//
//  SessionRowView.swift
//  Stuttering App
//
//  SwiftUI component to display session upload status.
//

import SwiftUI

struct SessionRowView: View {
    let session: MLSession
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color(.systemGray6))
                    .frame(width: 44, height: 44)
                
                Image(systemName: "waveform")
                    .foregroundColor(.primary)
            }
            
            // Text Details
            VStack(alignment: .leading, spacing: 4) {
                Text("Reading Session")
                    .font(.system(.headline, design: .rounded))
                
                Text(session.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Status Indicator
            statusIcon
        }
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch session.uploadStatus {
        case .pending:
            Image(systemName: "cloud")
                .foregroundColor(.secondary)
        case .uploading:
            ProgressView()
                .controlSize(.small)
                .tint(.secondary)
        case .success:
            Image(systemName: "checkmark.icloud.fill")
                .foregroundColor(.green)
                .font(.system(size: 20))
        case .failed:
            Image(systemName: "exclamationmark.icloud.fill")
                .foregroundColor(.red)
                .font(.system(size: 20))
        }
    }
}

// Preview
struct SessionRowView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            SessionRowView(session: MLSession(id: "1", date: Date(), uploadStatus: .uploading))
            SessionRowView(session: MLSession(id: "2", date: Date(), uploadStatus: .success))
        }
        .padding()
    }
}
