import re
import sys
import os

def fix_kotlin_version(project_dir):
    """Fix Kotlin version in a Flutter project's Gradle files."""
    print(f'\n=== Fixing Kotlin version for {project_dir} ===', flush=True)
    print(f'Current working directory: {os.getcwd()}', flush=True)
    print(f'Project dir absolute: {os.path.abspath(project_dir)}', flush=True)
    print(f'Project dir exists: {os.path.exists(project_dir)}', flush=True)
    
    # Fix root build.gradle (project level)
    root_build_gradle = os.path.join(project_dir, 'android', 'build.gradle')
    print(f'Looking for: {root_build_gradle}', flush=True)
    print(f'Exists: {os.path.exists(root_build_gradle)}', flush=True)
    
    if os.path.exists(root_build_gradle):
        with open(root_build_gradle, 'r') as f:
            content = f.read()
        
        print(f'Original content (first 1000 chars): {content[:1000]}', flush=True)
        
        # Replace kotlin_version line - handles both '<latest-version>' and version numbers
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
            print(f'UPDATED: {root_build_gradle}', flush=True)
        else:
            print(f'NO CHANGE NEEDED: {root_build_gradle}', flush=True)
        
        # Verify
        with open(root_build_gradle, 'r') as f:
            new_content = f.read()
        if 'kotlin_version = "1.9.10"' in new_content:
            print('SUCCESS: kotlin_version is now 1.9.10', flush=True)
        else:
            print('WARNING: kotlin_version may not have been updated correctly', flush=True)
            print(f'New content (first 1000 chars): {new_content[:1000]}', flush=True)
    else:
        print(f'NOT FOUND: {root_build_gradle}', flush=True)
        # List what's in the project dir
        android_dir = os.path.join(project_dir, 'android')
        if os.path.exists(android_dir):
            print(f'Contents of {android_dir}: {os.listdir(android_dir)}', flush=True)
        else:
            print(f'android dir does not exist: {android_dir}', flush=True)
    
    # Fix app build.gradle
    app_build_gradle = os.path.join(project_dir, 'android', 'app', 'build.gradle')
    print(f'Looking for: {app_build_gradle}', flush=True)
    print(f'Exists: {os.path.exists(app_build_gradle)}', flush=True)
    
    if os.path.exists(app_build_gradle):
        with open(app_build_gradle, 'r') as f:
            content = f.read()
        
        print(f'Processing: {app_build_gradle}', flush=True)
        
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
            print(f'UPDATED: {app_build_gradle}', flush=True)
        else:
            print(f'NO CHANGE NEEDED: {app_build_gradle}', flush=True)
    else:
        print(f'NOT FOUND: {app_build_gradle}', flush=True)
    
    # Fix settings.gradle
    settings_gradle = os.path.join(project_dir, 'android', 'settings.gradle')
    print(f'Looking for: {settings_gradle}', flush=True)
    print(f'Exists: {os.path.exists(settings_gradle)}', flush=True)
    
    if os.path.exists(settings_gradle):
        with open(settings_gradle, 'r') as f:
            content = f.read()
        
        print(f'Processing: {settings_gradle}', flush=True)
        
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
            print(f'UPDATED: {settings_gradle}', flush=True)
        else:
            print(f'NO CHANGE NEEDED: {settings_gradle}', flush=True)
    else:
        print(f'NOT FOUND: {settings_gradle}', flush=True)

if __name__ == '__main__':
    # Use absolute path from GITHUB_WORKSPACE if available
    github_workspace = os.environ.get('GITHUB_WORKSPACE', '.')
    print(f'GITHUB_WORKSPACE: {github_workspace}', flush=True)
    
    projects = ['customer_new', 'vendor_new', 'rider_new']
    for project in projects:
        full_path = os.path.join(github_workspace, project)
        fix_kotlin_version(full_path)
    
    print('\n=== Done ===', flush=True)