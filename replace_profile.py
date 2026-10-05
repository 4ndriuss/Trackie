import re

file_path = r'd:\Projects\Trackie\lib\pages\profile_tab.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

pattern = re.compile(r'                  // Foto Profil.*?const SizedBox\(height: AppSpacing\.xl\),\n                  ', re.DOTALL)

replacement = '''                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Foto Profil
                      GestureDetector(
                        onTap: () => _showImagePicker(context),
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
                              backgroundImage: userProfile?.photoUrl != null
                                  ? CachedNetworkImageProvider(userProfile!.photoUrl!)
                                  : null,
                              child: userProfile?.photoUrl == null
                                  ? Icon(
                                      Icons.person,
                                      size: 40,
                                      color: theme.primaryColor,
                                    )
                                  : null,
                            ),
                            if (authProvider.isLoading)
                              const Positioned.fill(
                                child: CircularProgressIndicator(),
                              ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: theme.primaryColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      // Info Teks (Nama, Email, Info Kendaraan)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userProfile?.name ?? 'User',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (userProfile?.email != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                userProfile!.email,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textGrey,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 8),
                            // Kendaraan
                            if (userProfile?.vehicle != null && userProfile!.vehicle.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.two_wheeler,
                                      size: 14,
                                      color: theme.colorScheme.secondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        userProfile.vehicle,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.secondary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountPage()));
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: theme.primaryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: theme.primaryColor.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.add,
                                        size: 14,
                                        color: theme.primaryColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Tambah kendaraan',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.primaryColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Tombol Edit Profile
                      IconButton(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountPage()));
                        },
                        icon: Icon(
                          Icons.edit_outlined,
                          color: theme.colorScheme.secondary,
                        ),
                        tooltip: 'Edit Profil',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  '''

if pattern.search(content):
    content = pattern.sub(replacement, content)
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Success")
else:
    print("Pattern not found")
