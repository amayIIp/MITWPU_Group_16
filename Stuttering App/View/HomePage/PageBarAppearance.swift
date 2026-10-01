//
//  PageBarAppearance.swift
//  Spasht
//
//  One flat navigation bar for the whole app, installed once at launch.
//
//  iOS 26 made navigation bars transparent and moved the separation between bar
//  and content into the *scroll edge effect*. For an app whose pages are a flat
//  custom colour, that produces a visible seam: the effect paints the system
//  material — white, in light mode — behind the bar, and it meets the page's
//  lavender at a hard line straight across the screen. It is worst on the
//  screens with no tracked scroll view at all (these layouts pin their scroll
//  views above the safe area, so UIKit never finds one), where the bar simply
//  keeps whichever opaque appearance it resolved first.
//
//  Painting the bar in the page colour removes the seam by making both sides of
//  it the same colour, and clearing `shadowColor` removes the hairline that
//  used to be drawn under it. Content then disappears under the bar cleanly
//  rather than smearing through a blur.
//
//  Applied through `UINavigationBar.appearance()` rather than per screen: there
//  are more than a dozen scrolling screens across six storyboards, and the
//  per-screen version of this only ever reached four of them. A screen that
//  genuinely wants a different bar — the avatar cropper, which is black — still
//  overrides it on its own `navigationItem`.
//

import UIKit

//enum PageBarAppearance {
//
//    /// Installs the app-wide bar appearance. Call once, before any window exists.
//    static func installGlobally() {
//        let flat = UINavigationBarAppearance()
//        flat.configureWithOpaqueBackground()
//        flat.backgroundColor = UIColor(named: "bg") ?? .systemBackground
//        flat.shadowColor = .clear
//
//        let bar = UINavigationBar.appearance()
//        bar.standardAppearance = flat
//        bar.scrollEdgeAppearance = flat
//        bar.compactAppearance = flat
//        bar.compactScrollEdgeAppearance = flat
//    }


