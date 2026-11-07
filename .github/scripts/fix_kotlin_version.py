import re
import sys
import os

def fix_kotlin_version(project_dir):
    """Fix Kotlin version in a Flutter project's Gradle files."""
    print(f'\n=== Fixing Kotlin version for {project_dir} ===')
    print(f'Current working directory: {os.getcwd()}')
    print(f'Project dir exists: {os.path.exists(project_dir)}')
    
    # Fix root build.gradle (project level)
    root_build_gradle = os.path.join(project_dir, 'android', 'build.gradle')
    print(f'Looking for: {root_build_gradle}')
    print(f'Exists: {os.path.exists(root_build_gradle)}')
    
    if os.path.exists(root_build_gradle):
        with open(root_build_gradle, 'r') as f:
            content = f.read()
        
        print(f'Original content (first 1000 chars): {content[:1000]}')
        
        # Replace kotlin_version line - handles both '<latest-version>' and version numbers
        # Pattern matches: kotlin_version = '...' or kotlin_version = "..."
        original_content = content
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
        
        if content != original_content:
            with open(root_build_gradle, 'w') as f:
                f.write(content)
            print(f'UPDATED: {root_build_gradle}')
        else:
            print(f'NO CHANGE NEEDED: {root_build_gradle}')
        
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
    print(f'Looking for: {app_build_gradle}')
    print(f'Exists: {os.path.exists(app_build_gradle)}')
    
    if os.path.exists(app_build_gradle):
        with open(app_build_gradle, 'r') as f:
            content = f.read()
        
        print(f'Processing: {app_build_gradle}')
        
        # Handle classpath in buildscript dependencies
        original_content = content
        content = re.sub(
            r'classpath\s*[\'"]org\.jetbrains\.kotlin:kotlin-gradle-plugin:[0-9]+\.[0-9]+\.[0-9]+[\'"]',
            'classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.10"',
            content
        )
        
        if content != original_content:
            with open(app_build_gradle, 'w') as f:
                f.write(content)
            print(f'UPDATED: {app_build_gradle}')
        else:
            print(f'NO CHANGE NEEDED: {app_build_gradle}')
    else:
        print(f'NOT FOUND: {app_build_gradle}')
    
    # Fix settings.gradle
    settings_gradle = os.path.join(project_dir, 'android', 'settings.gradle')
    print(f'Looking for: {settings_gradle}')
    print(f'Exists: {os.path.exists(settings_gradle)}')
    
    if os.path.exists(settings_gradle):
        with open(settings_gradle, 'r') as f:
            content = f.read()
        
        print(f'Processing: {settings_gradle}')
        
        # Handle classpath in buildscript dependencies
        original_content = content
        content = re.sub(
            r'classpath\s*[\'"]org\.jetbrains\.kotlin:kotlin-gradle-plugin:[0-9]+\.[0-9]+\.[0-9]+[\'"]',
            'classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.10"',
            content
        )
        
        if content != original_content:
            with open(settings_gradle, 'w') as f:
                f.write(content)
            print(f'UPDATED: {settings_gradle}')
        else:
            print(f'NO CHANGE NEEDED: {settings_gradle}')
    else:
        print(f'NOT FOUND: {settings_gradle}')

if __name__ == '__main__':
    projects = ['customer_new', 'vendor_new', 'rider_new']
    for project in projects:
        fix_kotlin_version(project)
    
    print('\n=== Done ===')