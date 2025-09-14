//
//  OnboardingView.swift
//  Let's Talk
//
//  Created by Eric Carroll on 9/4/25.
//

import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("editLocked") private var editLocked: Bool = true

    @State private var pageIndex: Int = 0
    @State private var isAuthenticating: Bool = false
    @State private var authError: String?

    private let pages: [OnboardingPage] = [
        .init(
            title: String(localized: "Welcome to Let's Talk"),
            message: String(localized: "Tap tiles to speak words and phrases. Use Favorites and Quick Phrases to build messages fast."),
            systemImage: "message.circle.fill",
            accentColor: .blue
        ),
        .init(
            title: String(localized: "Guided Edit Lock"),
            message: String(localized: "Editing is locked by default to prevent accidental changes. You can unlock editing to add, reorder, and delete tiles and pages."),
            systemImage: "lock.fill",
            accentColor: .orange
        ),
        .init(
            title: String(localized: "Unlock When You Need To"),
            message: String(localized: "Use Face ID / Touch ID or passcode to temporarily unlock editing. You can always re-lock in Settings."),
            systemImage: "lock.open.fill",
            accentColor: .green
        )
    ]

    var body: some View {
        NavigationStack {
            VStack {
                TabView(selection: $pageIndex) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { idx, page in
                        OnboardingCard(page: page)
                            .tag(idx)
                            .padding()
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))

                if let authError {
                    Text(authError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.top, 4)
                }

                HStack(spacing: 12) {
                    Button {
                        finishOnboarding(unlock: false)
                    } label: {
                        Text(String(localized: "Skip"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    if pageIndex < pages.count - 1 {
                        Button {
                            withAnimation { pageIndex = min(pageIndex + 1, pages.count - 1) }
                        } label: {
                            Text(String(localized: "Next"))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button {
                            Task { await unlockAndFinish() }
                        } label: {
                            if isAuthenticating {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text(String(localized: "Unlock Editing"))
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
            .navigationTitle(String(localized: "Getting Started"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Done")) {
                        finishOnboarding(unlock: false)
                    }
                    .accessibilityHint(Text(String(localized: "Finish onboarding and keep editing locked")))
                }
            }
        }
        .interactiveDismissDisabled(true) // ensure completion flag is set
    }

    private func finishOnboarding(unlock: Bool) {
        if unlock == false {
            editLocked = true
        }
        hasCompletedOnboarding = true
        authError = nil
        dismiss()
    }

    @MainActor
    private func unlockAndFinish() async {
        isAuthenticating = true
        authError = nil
        let success = await AuthService.authenticate(reason: String(localized: "Unlock editing to modify tiles and pages."))
        isAuthenticating = false
        if success {
            editLocked = false
            hasCompletedOnboarding = true
            dismiss()
        } else {
            authError = String(localized: "Authentication failed. You can try again or finish and keep editing locked.")
        }
    }
}

private struct OnboardingPage: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let message: String
    let systemImage: String
    let accentColor: Color
}

private struct OnboardingCard: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: page.systemImage)
                .font(.system(size: 72, weight: .bold))
                .foregroundStyle(page.accentColor)
                .padding(.bottom, 8)
            Text(page.title)
                .font(.title2)
                .bold()
                .multilineTextAlignment(.center)
            Text(page.message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

