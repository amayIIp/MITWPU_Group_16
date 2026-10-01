//
//  AvatarStore.swift
//  Spasht
//
//  The user's profile photo: one JPEG per user, cached in the app container and
//  mirrored into the `avatars` Storage bucket for account holders.
//
//  The local file is the source of truth for display, so the photo is there the
//  instant it is picked and on every launch after, with no network round trip
//  and no placeholder flash. The cloud copy exists only so the photo survives a
//  reinstall or a sign-in on another device.
//
//  Every cloud call is best-effort and swallowed: if the bucket or the
//  `avatar_url` column hasn't been created yet, picking a photo still works and
//  still shows — it just stays on this device.
//
//  Guest mode never touches the network, matching the rest of guest mode: what
//  a guest does stays on the device.
//

import UIKit
import Supabase

enum AvatarStore {

    /// Posted whenever the current user's photo is set, replaced or removed, so
    /// every screen showing it can refresh without polling.
    static let didChangeNotification = Notification.Name("ProfileAvatarUpdated")

    /// Must match the bucket created in the Supabase dashboard.
    static let bucket = "avatars"

    /// Square, and small enough that a slow connection is never a reason not to
    /// have a photo — 512px at 0.8 quality lands around 60–90 KB.
    private static let maxDimension: CGFloat = 512
    private static let compressionQuality: CGFloat = 0.8

    private static var client: SupabaseClient { SupabaseManager.shared.client }

    // MARK: - Reading

    static func image(for userId: String?) -> UIImage? {
        guard let userId,
              let url = localURL(for: userId),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return UIImage(data: data)
    }

    /// The signed-in (or guest) user's photo, if they have one.
    static var currentImage: UIImage? {
        image(for: LogManager.shared.getCurrentUserId())
    }

    /// The side, in points, to render a profile-header avatar at.
    ///
    /// Rendering to a fixed size is not just cosmetic. A `UIImageView`'s
    /// intrinsic content size *is* its image's size, and both avatar views sit
    /// in a stack view that has no width of its own — so handing them the
    /// stored 512pt photo stretched the whole header to 512pt wide, and the
    /// circular mask then cut a magnified sliver out of the middle of the
    /// resulting strip. The storyboard's `width >= 109` cannot prevent that.
    static let headerDiameter: CGFloat = 120

    /// The photo drawn as a filled circle at `diameter` points, for the places
    /// that can't mask a layer — a bar button's image, say. The stored file is
    /// already square, so this is a straight scale with no distortion.
    ///
    /// The renderer defaults to the screen's scale, so the result is sized in
    /// points but backed by full-resolution pixels.
    static func circularImage(for userId: String?, diameter: CGFloat) -> UIImage? {
        guard let source = image(for: userId) else { return nil }

        let size = CGSize(width: diameter, height: diameter)
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false

        let circle = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).addClip()
            source.draw(in: CGRect(origin: .zero, size: size))
        }
        // Original, or the bar button would tint the photo flat.
        return circle.withRenderingMode(.alwaysOriginal)
    }

    static func hasImage(for userId: String?) -> Bool {
        guard let userId, let url = localURL(for: userId) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    // MARK: - Writing

    /// Normalises `image` to a centred square, writes it locally, and starts the
    /// upload. Returns the version that was actually stored, so the caller can
    /// show exactly what it saved.
    @discardableResult
    static func save(_ image: UIImage, for userId: String) -> UIImage? {
        guard let squared = normalised(image),
              let data = squared.jpegData(compressionQuality: compressionQuality),
              let url = localURL(for: userId)
        else { return nil }

        do {
            try data.write(to: url, options: .atomic)
        } catch {
            print("⚠️ [AVATAR] Couldn't save locally: \(error.localizedDescription)")
            return nil
        }

        notifyChanged()

        if SessionManager.shared.isAccountMode {
            upload(data: data, userId: userId)
        }
        return squared
    }

    static func remove(for userId: String) {
        removeLocal(for: userId)
        notifyChanged()

        if SessionManager.shared.isAccountMode {
            deleteRemote(userId: userId)
        }
    }

    // MARK: - Local file

    private static var directory: URL? {
        let fm = FileManager.default
        guard let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else { return nil }

        let dir = base.appendingPathComponent("Avatars", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private static func localURL(for userId: String) -> URL? {
        // Guest ids and Supabase UUIDs are both filename-safe, but a stray path
        // separator would escape the directory, so it is encoded out.
        let safe = userId.replacingOccurrences(of: "/", with: "_")
        return directory?.appendingPathComponent("\(safe).jpg")
    }

    private static func removeLocal(for userId: String) {
        guard let url = localURL(for: userId) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// Used by account deletion: nothing identifying should survive it.
    static func removeAllLocal() {
        guard let dir = directory else { return }
        try? FileManager.default.removeItem(at: dir)
    }

    // MARK: - Cloud

    /// The object path inside the bucket.
    ///
    /// **Lowercased on purpose.** Every user id in this app comes from Swift's
    /// `UUID.uuidString`, which Foundation renders in UPPERCASE, while Postgres
    /// renders a uuid in lowercase — so `auth.uid()::text` is lowercase. The
    /// bucket policy compares the first path segment against that as plain
    /// text, with none of the case-insensitive normalisation a real `uuid`
    /// column would apply. Upload the uppercase form and every write is refused
    /// by RLS, silently, while every `profiles` row keeps working.
    private static func remotePath(for userId: String) -> String {
        "\(userId.lowercased())/avatar.jpg"
    }

    private static func upload(data: Data, userId: String) {
        let path = remotePath(for: userId)
        Task {
            do {
                try await client.storage
                    .from(bucket)
                    .upload(path,
                            data: data,
                            options: FileOptions(cacheControl: "3600",
                                                 contentType: "image/jpeg",
                                                 upsert: true))

                // A partial upsert leaves every column it doesn't mention alone,
                // so this can't clobber the name or onboarding flag.
                try await client
                    .from("profiles")
                    .upsert(["id": .string(userId), "avatar_url": .string(path)] as [String: AnyJSON])
                    .execute()

                print("☁️ ✅ [AVATAR] Uploaded")
            } catch {
                // Kept local either way, and retried by `syncWithCloud` on the
                // next sign-in. An RLS message here means the bucket policies
                // don't match the path — check the casing first.
                print("⚠️ [AVATAR] Upload failed, photo kept on this device only")
                print("⚠️ [AVATAR] path=\(path) error=\(error)")
            }
        }
    }

    private static func deleteRemote(userId: String) {
        let path = remotePath(for: userId)
        Task {
            do {
                _ = try await client.storage.from(bucket).remove(paths: [path])
                try await client
                    .from("profiles")
                    .upsert(["id": .string(userId), "avatar_url": .null] as [String: AnyJSON])
                    .execute()
                print("☁️ ✅ [AVATAR] Removed")
            } catch {
                print("⚠️ [AVATAR] Remote removal failed: \(error.localizedDescription)")
            }
        }
    }

    /// Reconciles the photo with the cloud after a sign-in, in whichever
    /// direction is needed: pull it down onto a fresh install, or push a local
    /// one the cloud never received.
    ///
    /// The push half is the repair path. An upload can fail — no network, a
    /// bucket that isn't set up yet — and nothing else would ever retry it, so
    /// the photo would stay on one device forever. Note it does *not* delete a
    /// local photo when the cloud has none: "the server doesn't have it" is
    /// exactly what a failed upload looks like, and destroying the user's photo
    /// on that evidence is the worst reading of it.
    ///
    /// Never throws: this runs inside the transactional sign-in, where throwing
    /// would roll back the whole sign-in over a picture.
    static func syncWithCloud(userId: String) async {
        struct Row: Decodable { let avatar_url: String? }

        do {
            let rows: [Row] = try await client
                .from("profiles")
                .select("avatar_url")
                .eq("id", value: userId)
                .limit(1)
                .execute()
                .value

            if let path = rows.first?.avatar_url, !path.isEmpty {
                let data = try await client.storage.from(bucket).download(path: path)
                guard let url = localURL(for: userId) else { return }
                try data.write(to: url, options: .atomic)
                notifyChanged()
                print("☁️ ✅ [AVATAR] Restored from cloud")

            } else if let url = localURL(for: userId),
                      let data = try? Data(contentsOf: url) {
                print("☁️ [AVATAR] Cloud has no photo but this device does — re-uploading")
                upload(data: data, userId: userId)
            }

        } catch {
            print("⚠️ [AVATAR] Cloud sync skipped: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    /// Centre-crops to a square and scales down, flattening the orientation flag
    /// in the process — a photo straight from the camera is otherwise stored
    /// sideways by anything that reads the raw bytes.
    private static func normalised(_ image: UIImage) -> UIImage? {
        let side = min(image.size.width, image.size.height)
        guard side > 0 else { return nil }

        let target = min(side, maxDimension)
        let scale = target / side
        let origin = CGPoint(x: (image.size.width - side) / 2 * scale,
                             y: (image.size.height - side) / 2 * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: CGSize(width: target, height: target),
                                       format: format).image { _ in
            image.draw(in: CGRect(x: -origin.x,
                                  y: -origin.y,
                                  width: image.size.width * scale,
                                  height: image.size.height * scale))
        }
    }

    private static func notifyChanged() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: didChangeNotification, object: nil)
        }
    }
}
