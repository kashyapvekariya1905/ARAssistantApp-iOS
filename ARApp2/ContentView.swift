// ContentView.swift
import SwiftUI
import ARKit
import SceneKit

struct ContentView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("AR Remote Assist")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                
                Text("Select your role:")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 20) {
                    NavigationLink(destination: UserARView()) {
                        RoleSelectionCard(
                            title: "User",
                            subtitle: "Stream AR camera and receive annotations",
                            icon: "camera.viewfinder",
                            color: .green
                        )
                    }
                    
                    NavigationLink(destination: AidDrawingView()) {
                        RoleSelectionCard(
                            title: "Assistant",
                            subtitle: "View stream and create 3D annotations",
                            icon: "pencil.and.outline",
                            color: .blue
                        )
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationBarHidden(true)
        }
    }
}

struct RoleSelectionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundColor(color)
                .frame(width: 60)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}



















//import SwiftUI
//import ARKit
//import SceneKit
//
//struct ContentView: View {
//    var body: some View {
//        NavigationView {
//            // Main content view
//            MainContentView()
//        }
//        .navigationViewStyle(StackNavigationViewStyle()) // Force single view style on iPad
//    }
//}
//
//struct MainContentView: View {
//    var body: some View {
//        VStack(spacing: 30) {
//            Text("AR Remote Assist")
//                .font(.largeTitle)
//                .fontWeight(.bold)
//                .padding()
//            
//            Text("Select your role:")
//                .font(.headline)
//                .foregroundColor(.secondary)
//            
//            VStack(spacing: 20) {
//                NavigationLink(destination: UserARView()) {
//                    RoleSelectionCard(
//                        title: "User",
//                        subtitle: "Stream AR camera and receive annotations",
//                        icon: "camera.viewfinder",
//                        color: .green
//                    )
//                }
//                .buttonStyle(PlainButtonStyle()) // Remove default button styling
//                
//                NavigationLink(destination: AidDrawingView()) {
//                    RoleSelectionCard(
//                        title: "Assistant",
//                        subtitle: "View stream and create 3D annotations",
//                        icon: "pencil.and.outline",
//                        color: .blue
//                    )
//                }
//                .buttonStyle(PlainButtonStyle()) // Remove default button styling
//            }
//            .padding(.horizontal)
//            
//            Spacer()
//        }
//        .navigationBarHidden(true)
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
//        .background(Color(.systemBackground))
//    }
//}
//
//struct RoleSelectionCard: View {
//    let title: String
//    let subtitle: String
//    let icon: String
//    let color: Color
//    
//    var body: some View {
//        HStack {
//            Image(systemName: icon)
//                .font(.largeTitle)
//                .foregroundColor(color)
//                .frame(width: 60)
//            
//            VStack(alignment: .leading, spacing: 4) {
//                Text(title)
//                    .font(.headline)
//                    .fontWeight(.semibold)
//                    .foregroundColor(.primary)
//                
//                Text(subtitle)
//                    .font(.subheadline)
//                    .foregroundColor(.secondary)
//                    .multilineTextAlignment(.leading)
//            }
//            
//            Spacer()
//            
//            Image(systemName: "chevron.right")
//                .foregroundColor(.secondary)
//        }
//        .padding()
//        .background(Color(.systemGray6))
//        .cornerRadius(12)
//        .contentShape(Rectangle()) // Make entire card tappable
//    }
//}
//
//// Alternative approach using NavigationStack (iOS 16+)
//@available(iOS 16.0, *)
//struct ContentViewModern: View {
//    var body: some View {
//        NavigationStack {
//            VStack(spacing: 30) {
//                Text("AR Remote Assist")
//                    .font(.largeTitle)
//                    .fontWeight(.bold)
//                    .padding()
//                
//                Text("Select your role:")
//                    .font(.headline)
//                    .foregroundColor(.secondary)
//                
//                VStack(spacing: 20) {
//                    NavigationLink(destination: UserARView()) {
//                        RoleSelectionCard(
//                            title: "User",
//                            subtitle: "Stream AR camera and receive annotations",
//                            icon: "camera.viewfinder",
//                            color: .green
//                        )
//                    }
//                    .buttonStyle(PlainButtonStyle())
//                    
//                    NavigationLink(destination: AidDrawingView()) {
//                        RoleSelectionCard(
//                            title: "Assistant",
//                            subtitle: "View stream and create 3D annotations",
//                            icon: "pencil.and.outline",
//                            color: .blue
//                        )
//                    }
//                    .buttonStyle(PlainButtonStyle())
//                }
//                .padding(.horizontal)
//                
//                Spacer()
//            }
//            .navigationBarHidden(true)
//            .frame(maxWidth: .infinity, maxHeight: .infinity)
//            .background(Color(.systemBackground))
//        }
//    }
//}
//
//#Preview {
//    ContentView()
//}
