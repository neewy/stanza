import SwiftUI
import SwiftData

struct ManageCategoriesSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.name) private var categories: [Category]
    
    // Quick Category Creation
    @State private var newCategoryName = ""
    @State private var newCategoryColor: Color = .blue
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Manage Categories")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            VStack {
                // Header for creating categories cleanly
                HStack {
                    TextField("New Category Name", text: $newCategoryName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addCategory)
                    
                    ColorPicker("", selection: $newCategoryColor)
                        .labelsHidden()
                    
                    Button(action: addCategory) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    .disabled(newCategoryName.isEmpty)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                
                List {
                    if categories.isEmpty {
                        Text("No categories centrally defined yet.")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(categories) { category in
                            CategoryRowView(category: category) {
                                modelContext.delete(category)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 400, height: 500)
    }
    
    private func addCategory() {
        guard !newCategoryName.isEmpty else { return }
        let newCat = Category(name: newCategoryName, hexColor: newCategoryColor.toHex())
        modelContext.insert(newCat)
        newCategoryName = ""
    }
}

struct CategoryRowView: View {
    @Bindable var category: Category
    @State private var localColor: Color
    var onDelete: () -> Void
    
    init(category: Category, onDelete: @escaping () -> Void) {
        self.category = category
        self.onDelete = onDelete
        _localColor = State(initialValue: category.color)
    }
    
    var body: some View {
        HStack {
            TextField("Category Name", text: $category.name)
                .textFieldStyle(.roundedBorder)
            
            Spacer()
            
            ColorPicker("", selection: $localColor)
                .labelsHidden()
                .onChange(of: localColor) { _, newColor in
                    category.hexColor = newColor.toHex()
                }
                
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .frame(width: 20)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}
