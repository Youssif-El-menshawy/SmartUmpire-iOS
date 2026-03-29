import SwiftUI

struct CheckCircle: View {
    let isChecked: Bool
    var disabled: Bool = false

    var body: some View {
        Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 22))
            .foregroundColor(disabled ? .textSecondary : (isChecked ? .primaryBlue : .textSecondary))
    }
}
