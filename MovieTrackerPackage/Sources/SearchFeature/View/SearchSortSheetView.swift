import DesignSystem
import SwiftUI

struct SearchSortSheetView: View {
    private let presenter: SearchSortSheetPresenter
    @Environment(\.dismiss) private var dismiss

    init(presenter: SearchSortSheetPresenter) {
        self.presenter = presenter
    }

    var body: some View {
        NavigationStack {
            List(SearchSortOption.allCases, id: \.self) { option in
                Button {
                    presenter.selectSort(option)
                } label: {
                    HStack {
                        Text(option.label)
                            .foregroundStyle(.primary)
                        Spacer()
                        if presenter.draftSort == option {
                            Image.checkmark
                                .foregroundStyle(Color.accent)
                        }
                    }
                }
            }
            .navigationTitle("Sort By")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        presenter.confirm()
                        dismiss()
                    }
                }
            }
        }
    }
}
