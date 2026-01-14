# Ours Lists - Xcode Setup Guide

## Prerequisites

- Xcode 15.0+
- iOS 17.0+ target
- Apple Developer account (for CloudKit)
- Two devices with different Apple IDs (for testing sharing)

## Step 1: Create Xcode Project

1. Open Xcode → File → New → Project
2. Select **iOS** → **App**
3. Configure:
   - Product Name: `OursLists`
   - Team: Your Apple Developer Team
   - Organization Identifier: `org.laurastrandt`
   - Bundle Identifier: `org.laurastrandt.OursLists`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Storage: **None** (we'll add Core Data manually)
4. Click **Create**

## Step 2: Add Capabilities

1. Select your project in the navigator
2. Select the **OursLists** target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability** and add:

### iCloud
- Check **CloudKit**
- Check **Key-value storage** (optional, for preferences)
- Under Containers, click **+** and add: `iCloud.org.laurastrandt.OursLists`

### Background Modes (optional but recommended)
- Check **Remote notifications** (for CloudKit push)

## Step 3: Configure Entitlements

Your `OursLists.entitlements` file should contain:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>aps-environment</key>
    <string>development</string>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.org.laurastrandt.OursLists</string>
    </array>
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudKit</string>
    </array>
</dict>
</plist>
```

## Step 4: Create Core Data Model

1. File → New → File → **Data Model** (under Core Data)
2. Name it `OursLists.xcdatamodeld`
3. Create the following entities:

### Entity: Space
| Attribute | Type | Optional |
|-----------|------|----------|
| id | UUID | No |
| name | String | Yes |
| createdAt | Date | Yes |
| ownerName | String | Yes |
| isShared | Boolean | No (default: false) |
| shareRecordData | Binary Data | Yes |

**Relationships:**
- `groceryLists` → To Many → GroceryList (inverse: space)
- `chores` → To Many → Chore (inverse: space)
- `projects` → To Many → Project (inverse: space)

### Entity: GroceryList
| Attribute | Type | Optional |
|-----------|------|----------|
| id | UUID | No |
| name | String | Yes |
| createdAt | Date | Yes |

**Relationships:**
- `space` → To One → Space (inverse: groceryLists)
- `items` → To Many → GroceryItem (inverse: groceryList)

### Entity: GroceryItem
| Attribute | Type | Optional |
|-----------|------|----------|
| id | UUID | No |
| title | String | Yes |
| quantity | String | Yes |
| note | String | Yes |
| isChecked | Boolean | No (default: false) |
| category | String | Yes |
| createdBy | String | Yes |
| createdAt | Date | Yes |
| updatedAt | Date | Yes |

**Relationships:**
- `groceryList` → To One → GroceryList (inverse: items)

### Entity: Chore
| Attribute | Type | Optional |
|-----------|------|----------|
| id | UUID | No |
| title | String | Yes |
| frequency | String | Yes |
| customDays | Integer 16 | No (default: 7) |
| assignedTo | String | Yes |
| lastDoneAt | Date | Yes |
| isPaused | Boolean | No (default: false) |
| notes | String | Yes |
| createdAt | Date | Yes |

**Relationships:**
- `space` → To One → Space (inverse: chores)

### Entity: Project
| Attribute | Type | Optional |
|-----------|------|----------|
| id | UUID | No |
| name | String | Yes |
| isArchived | Boolean | No (default: false) |
| color | String | Yes |
| createdAt | Date | Yes |

**Relationships:**
- `space` → To One → Space (inverse: projects)
- `tasks` → To Many → Task (inverse: project)

### Entity: Task
| Attribute | Type | Optional |
|-----------|------|----------|
| id | UUID | No |
| title | String | Yes |
| note | String | Yes |
| createdAt | Date | Yes |
| completedAt | Date | Yes |
| priority | Integer 16 | No (default: 1) |
| assignedTo | String | Yes |
| dueDate | Date | Yes |

**Relationships:**
- `project` → To One → Project (inverse: tasks)

## Step 5: Configure Model for CloudKit

1. Select the `OursLists.xcdatamodeld` file
2. In the Data Model Inspector (right panel):
   - For each entity, check **"Used with CloudKit"**
3. Set **Codegen** to **Manual/None** for all entities (we provide custom classes)

## Step 6: Add Source Files

Copy all the `.swift` files from the `OursLists/OursLists/` folder structure into your Xcode project:

```
OursLists/
├── App/
│   ├── OursListsApp.swift
│   └── SceneDelegate.swift
├── Models/
│   ├── Space+CoreDataClass.swift
│   ├── GroceryList+CoreDataClass.swift
│   ├── GroceryItem+CoreDataClass.swift
│   ├── Chore+CoreDataClass.swift
│   ├── Project+CoreDataClass.swift
│   └── Task+CoreDataClass.swift
├── Services/
│   ├── PersistenceController.swift
│   └── CloudKitSharingService.swift
└── Views/
    ├── RootView.swift
    ├── MainTabView.swift
    ├── Onboarding/
    │   └── OnboardingView.swift
    ├── Groceries/
    │   ├── GroceriesTab.swift
    │   └── GroceryListDetailView.swift
    ├── Chores/
    │   └── ChoresTab.swift
    ├── Projects/
    │   ├── ProjectsTab.swift
    │   └── ProjectDetailView.swift
    └── Settings/
        └── SettingsView.swift
```

## Step 7: Configure Info.plist

Add these keys to support CloudKit sharing:

```xml
<key>CKSharingSupported</key>
<true/>
<key>NSUbiquitousContainers</key>
<dict>
    <key>iCloud.org.laurastrandt.OursLists</key>
    <dict>
        <key>NSUbiquitousContainerIsDocumentScopePublic</key>
        <false/>
        <key>NSUbiquitousContainerName</key>
        <string>Ours Lists</string>
        <key>NSUbiquitousContainerSupportedFolderLevels</key>
        <string>None</string>
    </dict>
</dict>
```

## Step 8: Configure Scene Delegate for Share Acceptance

Add to Info.plist to enable SceneDelegate:

```xml
<key>UIApplicationSceneManifest</key>
<dict>
    <key>UIApplicationSupportsMultipleScenes</key>
    <false/>
    <key>UISceneConfigurations</key>
    <dict>
        <key>UIWindowSceneSessionRoleApplication</key>
        <array>
            <dict>
                <key>UISceneConfigurationName</key>
                <string>Default Configuration</string>
                <key>UISceneDelegateClassName</key>
                <string>$(PRODUCT_MODULE_NAME).SceneDelegate</string>
            </dict>
        </array>
    </dict>
</dict>
```

## Step 9: CloudKit Dashboard Setup

1. Go to [CloudKit Dashboard](https://icloud.developer.apple.com/)
2. Select your container: `iCloud.org.laurastrandt.OursLists`
3. The schema will be auto-created when you first run the app
4. For production, deploy schema to Production environment

## Testing CloudKit Sharing

### Device 1 (Owner):
1. Sign in with Apple ID #1
2. Launch app, create household
3. Go to Settings → Share Household
4. Send invitation to Apple ID #2

### Device 2 (Invitee):
1. Sign in with Apple ID #2
2. Accept invitation (via notification or Messages)
3. App should show shared household

### Troubleshooting:
- Ensure both devices have iCloud signed in
- Check CloudKit Dashboard for sync status
- Use `NSPersistentCloudKitContainer.eventChangedNotification` to debug
- Check Console.app for CloudKit errors

## MVP Milestone Plan

### Phase 1: Local-Only (Day 1-2)
- [ ] Create Xcode project with Core Data model
- [ ] Implement all views without CloudKit
- [ ] Test all CRUD operations locally
- [ ] Verify data persistence across app launches

### Phase 2: Enable CloudKit Sync (Day 3)
- [ ] Add iCloud capability and container
- [ ] Configure NSPersistentCloudKitContainer
- [ ] Test single-user sync across devices (same Apple ID)
- [ ] Verify offline/online transitions

### Phase 3: Add Sharing (Day 4-5)
- [ ] Implement CKShare creation for Space
- [ ] Add UICloudSharingController presentation
- [ ] Handle share acceptance via SceneDelegate
- [ ] Test two-user sharing with different Apple IDs
- [ ] Verify read/write permissions for both users

### Phase 4: Polish (Day 6+)
- [ ] Add error handling and user feedback
- [ ] Optimize sync performance
- [ ] Add conflict resolution UI (if needed)
- [ ] Test edge cases (offline edits, simultaneous edits)

## Architecture Notes

### Why Core Data + NSPersistentCloudKitContainer?

1. **Mature CKShare Support**: NSPersistentCloudKitContainer has built-in, well-tested CloudKit Sharing since iOS 15

2. **Automatic Zone Management**: The container handles creating and managing CKRecordZone for shared data

3. **Offline-First**: Core Data provides robust local storage; CloudKit syncs when available

4. **Conflict Resolution**: Last-write-wins is handled automatically by the merge policy

### Data Flow

```
User Action
    ↓
SwiftUI View (updates)
    ↓
Core Data Context (save)
    ↓
NSPersistentCloudKitContainer
    ↓
CloudKit (sync when online)
    ↓
Other User's Device (notification → fetch → merge)
```

### Sharing Flow

```
Owner creates Space
    ↓
Owner taps "Share"
    ↓
App creates CKShare for Space
    ↓
UICloudSharingController shows invitation UI
    ↓
Invitee receives notification/link
    ↓
Invitee accepts (SceneDelegate handles CKShare.Metadata)
    ↓
Both users now see shared Space and all child objects
```
