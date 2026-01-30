import SwiftUI

struct SignInView: View {
    @EnvironmentObject var authService: AuthenticationService

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "house.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)

                Text("Our Home")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Keep your household organized together")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(spacing: 16) {
                Button {
                    Task {
                        await authService.signInWithGoogle()
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.title3)
                        Text("Sign in with Google")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if let error = authService.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 32)

            Spacer()
                .frame(height: 60)
        }
    }
}
