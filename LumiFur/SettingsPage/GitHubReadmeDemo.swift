//
//  GitHubReadmeDemo.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 14/05/2026.
//


import SwiftUI

struct GitHubReadmeDemo: View {
  private let about = """
    This screen shows how LumiFur renders a repository’s `README.md`
    and uses a custom `OpenURLAction` to scroll to headings from anchor
    links.
    """

  @StateObject private var model = Model()
  @State private var wrapCode = false

  var body: some View {
    ScrollViewReader { proxy in
      content
        .scrollToHeadings(using: proxy)
    }
  }

  @ViewBuilder
  private var content: some View {
    Form {
      DisclosureGroup("About this demo") {
        MarkdownTextView(markdown: self.about)
      }
      Section("Repository") {
        TextField("Owner", text: $model.owner)
        TextField("Repo", text: $model.repo)
        Button {
          Task { @MainActor in
            await model.load()
          }
        } label: {
          Text(model.isLoading ? "Loading..." : "Load `README`")
        }
        .disabled(model.isLoading)
      }
      #if os(iOS) || os(visionOS)
        .textInputAutocapitalization(.none)
      #endif
      .autocorrectionDisabled(true)

      if let state = model.state {
        switch state {
        case .success(let success):
          Section {
            Toggle("Wrap Code Blocks", isOn: $wrapCode)
          }
          MarkdownTextView(markdown: success.content)
        case .failure:
          LegacyUnavailableView("Loading Failed", systemImage: "exclamationmark.triangle.fill")
        }
      }
    }
  }
}

extension View {
  func scrollToHeadings(using scrollViewProxy: ScrollViewProxy) -> some View {
    self.environment(
      \.openURL,
      OpenURLAction { url in
        guard let fragment = url.fragment?.lowercased() else {
          return .systemAction
        }
        withAnimation {
          scrollViewProxy.scrollTo(fragment, anchor: .top)
        }
        return .handled
      }
    )
  }
}

extension GitHubReadmeDemo {
  @MainActor final class Model: ObservableObject {
    struct State: Equatable, Sendable {
      let content: String
      let baseURL: URL
      let imageBaseURL: URL

      init(response: Response) {
        self.content =
          Data(
            base64Encoded: response.content,
            options: .ignoreUnknownCharacters
          ).flatMap {
            String(decoding: $0, as: UTF8.self)
          } ?? ""
        self.baseURL = response.htmlURL.deletingLastPathComponent()
        self.imageBaseURL = response.downloadURL.deletingLastPathComponent()
      }
    }

    struct Response: Decodable, Sendable {
      private enum CodingKeys: String, CodingKey {
        case content
        case htmlURL = "html_url"
        case downloadURL = "download_url"
      }

      let content: String
      let htmlURL: URL
      let downloadURL: URL
    }

    @Published var owner = "stef1949"
    @Published var repo = "lumifur"
    @Published var isLoading = false

    @Published var state: Result<State, Error>?

    func load() async {
      isLoading = true
      defer { isLoading = false }

      do {
        let (data, _) = try await URLSession.shared
          .data(from: URL(string: "https://api.github.com/repos/\(owner)/\(repo)/readme")!)
        let response = try JSONDecoder().decode(Response.self, from: data)
        self.state = .success(State(response: response))
      } catch {
        self.state = .failure(error)
      }
    }
  }
}

#Preview {
  GitHubReadmeDemo()
}
