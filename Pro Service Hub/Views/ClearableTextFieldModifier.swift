//
//  ClearableTextFieldModifier.swift
//  Pro Service Hub
//
//  Created by Codex.
//

import SwiftUI

private struct ClearableTextFieldModifier: ViewModifier {
    @Binding var text: String
    let action: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .padding(.trailing, 28)
            .overlay(alignment: .trailing) {
                if !text.isEmpty {
                    Button {
                        if let action {
                            action()
                        } else {
                            text = ""
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.trailing, 8)
                }
            }
    }
}

extension View {
    func clearButton(text: Binding<String>, action: (() -> Void)? = nil) -> some View {
        modifier(ClearableTextFieldModifier(text: text, action: action))
    }
}
