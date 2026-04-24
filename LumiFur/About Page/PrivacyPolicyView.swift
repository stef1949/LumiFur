//
//  PrivacyPolicyView.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 01/01/2026.
//

import SwiftUI
import Textual

struct PrivacyPolicySection: Identifiable {
    let id = UUID()
    let heading: String   // e.g. "1) Who we are (Data Controller)"
    let markdown: String  // markdown for this section (including its heading)
}

struct PrivacyPolicyView: View {
    @State private var sections: [PrivacyPolicySection] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Form {
            if isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            } else if let errorMessage {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Failed to load privacy policy")
                            .font(.headline)
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                ForEach(sections) { section in
                    Section {
                        StructuredText(markdown: section.markdown)
                            //.textual.structuredTextStyle(.gitHub)
                            .textual.textSelection(.enabled)
                            .padding(.vertical, 4)
                    } header: {
                        //Text(section.heading)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadMarkdown()
        }
    }

    // MARK: - Loading & Preprocessing

    @MainActor
    private func loadMarkdown() async {
        guard let url = URL(string:
            "https://raw.githubusercontent.com/stef1949/LumiFur/main/docs/PRIVACY_POLICY.md"
        ) else {
            errorMessage = "Invalid URL."
            isLoading = false
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let raw = String(decoding: data, as: UTF8.self)

            sections = preprocessMarkdownIntoSections(raw)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            sections = []
        }

        isLoading = false
    }

    /// Preprocess the full Markdown into logical sections based on `##` headings.
    /// Everything before the first `##` becomes an "Overview" section.
    private func preprocessMarkdownIntoSections(_ markdown: String) -> [PrivacyPolicySection] {
        // Normalise line endings
        let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalized.components(separatedBy: .newlines)

        var sections: [PrivacyPolicySection] = []

        var currentHeading: String?
        var currentLines: [String] = []

        var preambleLines: [String] = []
        var hasSeenSectionHeading = false

        func flushCurrentSection() {
            guard let heading = currentHeading, !currentLines.isEmpty else { return }
            let sectionMarkdown = currentLines.joined(separator: "\n")
            sections.append(PrivacyPolicySection(heading: heading, markdown: sectionMarkdown))
        }

        for line in lines {
            if line.hasPrefix("## ") {
                // New section starting
                hasSeenSectionHeading = true
                flushCurrentSection()

                let headingText = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                currentHeading = headingText
                currentLines = [line]  // keep the "## ..." line in the section
            } else if !hasSeenSectionHeading {
                // Still in preamble (title + effective date etc.)
                preambleLines.append(line)
            } else {
                currentLines.append(line)
            }
        }

        // Flush last section
        flushCurrentSection()

        // Add preamble section if there is content before the first `##`
        let preambleBody = preambleLines
            .drop(while: { $0.trimmingCharacters(in: .whitespaces).isEmpty })
            .joined(separator: "\n")

        if !preambleBody.isEmpty {
            let heading = "Overview"
            let preambleMarkdown = preambleBody
            sections.insert(
                PrivacyPolicySection(heading: heading, markdown: preambleMarkdown),
                at: 0
            )
        }

        return sections
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}
 
