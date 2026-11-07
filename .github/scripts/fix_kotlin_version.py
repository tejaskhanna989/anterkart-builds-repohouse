import re
import sys
import os

def fix_kotlin_version(project_dir):
    """Fix Kotlin version in a Flutter project's Gradle files."""
    print(f'\n=== Fixing Kotlin version for {project_dir} ===', flush=True)
    print(f'Current working directory: {os.getcwd()}', flush=True)
    print(f'Project dir absolute: {os.path.abspath(project_dir)}', flush=True)
    print(f'Project dir exists: {os.path.exists(project_dir)}', flush=True)
    
    # Fix ROOT build.gradle (project level) - for classpath
    root_build_gradle = os.path.join(project_dir, 'android', 'build.gradle')
    print(f'Looking for: {root_build_gradle}', flush=True)
    print(f'Exists: {os.path.exists(root_build_gradle)}', flush=True)
    
    if os.path.exists(root_build_gradle):
        with open(root_build_gradle, 'r') as f:
            content = f.read()
        
        print(f'Original content length: {len(content)}', flush=True)
        print(f'Original content (first 3000 chars): {content[:3000]}', flush=True)
        
        # Handle classpath in buildscript dependencies
        original_content = content
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
    else:
        print(f'NOT FOUND: {root_build_gradle}', flush=True)
    
    # Fix APP build.gradle (app level) - this is where the plugins DSL is used
    app_build_gradle = os.path.join(project_dir, 'android', 'app', 'build.gradle')
    print(f'Looking for: {app_build_gradle}', flush=True)
    print(f'Exists: {os.path.exists(app_build_gradle)}', flush=True)
    
    if os.path.exists(app_build_gradle):
        with open(app_build_gradle, 'r') as f:
            content = f.read()
        
        print(f'Processing: {app_build_gradle}', flush=True)
        print(f'Content length: {len(content)}', flush=True)
        print(f'Content preview (first 5000 chars): {content[:5000]}', flush=True)
        
        original_content = content
        
        # Fix the plugins block - add version to kotlin-android plugin
        # First, let's see what the plugins block looks like
        print('Searching for kotlin-android in plugins block...', flush=True)
        for m in re.finditer(r'kotlin-android', content):
            start = max(0, m.start() - 100)
            end = min(len(content), m.end() + 100)
            print(f'Found "kotlin-android" at position {m.start()}: ...{content[start:end]}...', flush=True)
        
        # Fix the plugins block - add version to kotlin-android plugin
        # Match: id "kotlin-android" (without version) and add version
        # We need to match the id line and add version if not already present
        def add_version(match):
            full_match = match.group(0)
            if 'version' in full_match:
                return full_match
            return full_match.rstrip() + ' version "1.9.10"'
        
        # Match id "kotlin-android" or id 'kotlin-android' that doesn't have version on the same line
        content = re.sub(
            r'(id\s+[\'"]kotlin-android[\'"])(?![^\n]*version)',
            r'\1 version "1.9.10"',
            content
        )
        
        # Also handle classpath in buildscript dependencies
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
        
        # Verify
        with open(app_build_gradle, 'r') as f:
            new_content = f.read()
        if 'kotlin-android" version "1.9.10"' in new_content or "kotlin-android' version '1.9.10'" in new_content:
            print('SUCCESS: kotlin-android version is now 1.9.10 in app build.gradle', flush=True)
        else:
            print('WARNING: kotlin-android version may not have been updated correctly in app', flush=True)
            # Find where kotlin-android is
            for m in re.finditer(r'kotlin-android', new_content):
                print(f'Found "kotlin-android" at position {m.start()}: ...{new_content[max(0,m.start()-50):m.end()+50]}...', flush=True)
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