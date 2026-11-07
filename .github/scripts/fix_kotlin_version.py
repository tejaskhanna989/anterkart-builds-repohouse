import re
import sys
import os

def fix_kotlin_version(project_dir):
    """Fix Kotlin version in a Flutter project's Gradle files."""
    # Fix root build.gradle (project level)
    root_build_gradle = os.path.join(project_dir, 'android', 'build.gradle')
    if os.path.exists(root_build_gradle):
        with open(root_build_gradle, 'r') as f:
            content = f.read()
        
        print(f'Processing: {root_build_gradle}')
        print(f'Original content (first 1000 chars): {content[:1000]}')
        
        # Replace kotlin_version line - handles both '<latest-version>' and version numbers
        # Pattern matches: kotlin_version = '...' or kotlin_version = "..."
        content = re.sub(
            r'(kotlin_version\s*=\s*)[\'"][^\'"]*[\'"]',
            r'\1"1.9.10"',
            content
        )
        
        # Also handle classpath in buildscript dependencies
        content = re.sub(
            r'classpath\s*[\'"]org\.jetbrains\.kotlin:kotlin-gradle-plugin:[0-9]+\.[0-9]+\.[0-9]+[\'"]',
            'classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.10"',
            content
        )
        
        with open(root_build_gradle, 'w') as f:
            f.write(content)
        
        print(f'Updated: {root_build_gradle}')
        
        # Verify
        with open(root_build_gradle, 'r') as f:
            new_content = f.read()
        if 'kotlin_version = "1.9.10"' in new_content:
            print('SUCCESS: kotlin_version is now 1.9.10')
        else:
            print('WARNING: kotlin_version may not have been updated correctly')
            print(f'New content (first 1000 chars): {new_content[:1000]}')
    else:
        print(f'NOT FOUND: {root_build_gradle}')
    
    # Fix app build.gradle
    app_build_gradle = os.path.join(project_dir, 'android', 'app', 'build.gradle')
    if os.path.exists(app_build_gradle):
        with open(app_build_gradle, 'r') as f:
            content = f.read()
        
        print(f'Processing: {app_build_gradle}')
        
        # Handle classpath in buildscript dependencies
        content = re.sub(
            r'classpath\s*[\'"]org\.jetbrains\.kotlin:kotlin-gradle-plugin:[0-9]+\.[0-9]+\.[0-9]+[\'"]',
            'classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.10"',
            content
        )
        
        with open(app_build_gradle, 'w') as f:
            f.write(content)
        
        print(f'Updated: {app_build_gradle}')
    else:
        print(f'NOT FOUND: {app_build_gradle}')
    
    # Fix settings.gradle
    settings_gradle = os.path.join(project_dir, 'android', 'settings.gradle')
    if os.path.exists(settings_gradle):
        with open(settings_gradle, 'r') as f:
            content = f.read()
        
        print(f'Processing: {settings_gradle}')
        
        # Handle classpath in buildscript dependencies
        content = re.sub(
            r'classpath\s*[\'"]org\.jetbrains\.kotlin:kotlin-gradle-plugin:[0-9]+\.[0-9]+\.[0-9]+[\'"]',
            'classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.10"',
            content
        )
        
        with open(settings_gradle, 'w') as f:
            f.write(content)
        
        print(f'Updated: {settings_gradle}')
    else:
        print(f'NOT FOUND: {settings_gradle}')

if __name__ == '__main__':
    projects = ['customer_new', 'vendor_new', 'rider_new']
    for project in projects:
        print(f'\n=== Fixing Kotlin version for {project} ===')
        fix_kotlin_version(project)
    
    print('\n=== Done ===')