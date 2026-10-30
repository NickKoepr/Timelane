/// What the user picks when turning backup on while iCloud already holds a backup with data.
enum ExistingBackupChoice {
    case restore
    case replace
    case cancel
}
