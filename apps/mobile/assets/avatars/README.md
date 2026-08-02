# Avatar Assets

This folder must contain 12 avatar image files named:

  avatar-1.png  through  avatar-12.png

## How to add avatars

1. Place 12 PNG files here (recommended size: 200×200px, transparent background).
2. The files must follow the exact naming convention: `avatar-1.png`, `avatar-2.png`, ..., `avatar-12.png`.
3. The folder is already declared in `pubspec.yaml` so no changes are needed there.

## Why .gitkeep exists

The `.gitkeep` file ensures the empty directory is tracked by Git.
Once you add the actual avatar files, `.gitkeep` can be removed.

## Fallback behaviour

`AppConstants.avatarPath(id)` returns `assets/avatars/avatar-{id}.png`.
`Image.asset()` will use its `errorBuilder` to show a fallback icon if
the file is missing, so the app won't crash — but avatars will appear as
a placeholder person icon instead of the intended artwork.

## Recommended avatar sources

- Commission original chibi-style artwork
- Use royalty-free avatar packs (ensure license allows commercial use)
- Generate with AI art tools and export as PNG with transparency
