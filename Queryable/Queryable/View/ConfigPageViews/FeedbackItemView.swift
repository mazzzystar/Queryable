//
//  FeedbackItemView.swift
//  Queryable
//
//  Created by knight on 2023/10/28.
//

import SwiftUI

struct FeedbackItemView: View {
    let title: String
    let subtitle: String
    let logoIcon: Image
    let destination: URL
    
    var body: some View {
        Link(destination: destination, label: {
            HStack {
                logoIcon
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                    .shadow(radius: 2)
                Text(title)
                    .foregroundColor(.primary)
                Text(subtitle)
                    .foregroundColor(.gray)
            }
        })
        .foregroundColor(Color.primary)
    }
}

struct FeedbackItemView_Previews: PreviewProvider {
    static var previews: some View {
        FeedbackItemView(title: "Discord", subtitle:NSLocalizedString("discord/R3wNsqq3v5", comment: "Discord") , logoIcon: Image("DiscordIcon"), destination: URL(string: NSLocalizedString("https://discord.com/invite/R3wNsqq3v5", comment: "Discord URL"))!)
    }
}
