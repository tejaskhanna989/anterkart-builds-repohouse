import re
import sys
import os

def fix_kotlin_version(project_dir):
    """Fix Kotlin version in a Flutter project's Gradle files."""
    print(f'\n=== Fixing Kotlin version for {project_dir} ===', flush=True)
    print(f'Current working directory: {os.getcwd()}', flush=True)
    print(f'Project dir absolute: {os.path.abspath(project_dir)}', flush=True)
    print(f'Project dir exists: {os.path.exists(project_dir)}', flush=True)
    
    # Fix ROOT build.gradle (project level) - add ext.kotlin_version and classpath
    root_build_gradle = os.path.join(project_dir, 'android', 'build.gradle')
    print(f'Looking for ROOT: {root_build_gradle}', flush=True)
    print(f'ROOT Exists: {os.path.exists(root_build_gradle)}', flush=True)
    
    if os.path.exists(root_build_gradle):
        with open(root_build_gradle, 'r') as f:
            content = f.read()
        
        print(f'ROOT Original content length: {len(content)}', flush=True)
        print(f'ROOT Original content: {content}', flush=True)
        
        original_content = content
        
        # Add ext.kotlin_version = '1.9.10' in the ext block (or create ext block)
        # First, check if ext block exists
        if 'ext {' in content:
            print('ROOT: Found existing ext block', flush=True)
            # Add kotlin_version to existing ext block
            content = re.sub(
                r'(ext\s*\{[^}]*)',
                r'\1\n    kotlin_version = "1.9.10"',
                content,
                count=1
            )
        else:
            print('ROOT: No ext block found', flush=True)
            # Add ext block after buildscript or at the beginning
            if 'buildscript {' in content:
                print('ROOT: Found buildscript block', flush=True)
                # Add classpath if not present
                content = re.sub(
                    r'(buildscript\s*\{[^}]*dependencies\s*\{[^}]*)\}',
                    r'\1\n        classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.10"\n    }',
                    content,
                    count=1
                )
                # Add ext block after buildscript
                content = re.sub(
                    r'(buildscript\s*\{[^}]*\})',
                    r'\1\n\next {\n    kotlin_version = "1.9.10"\n}',
                    content,
                    count=1
                )
            else:
                print('ROOT: No buildscript block, adding ext at beginning', flush=True)
                # Add at the beginning
                content = 'ext {\n    kotlin_version = "1.9.10"\n}\n\n' + content
        
        # Also handle classpath in buildscript dependencies
        content = re.sub(
            r'classpath\s*[\'"]org\.jetbrains\.kotlin:kotlin-gradle-plugin:[0-9]+\.[0-9]+\.[0-9]+[\'"]',
            'classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.10"',
            content
        )
        
        # Also add classpath if not present in buildscript dependencies
        if 'classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.10"' not in content:
            if 'buildscript {' in content:
                content = re.sub(
                    r'(buildscript\s*\{[^}]*dependencies\s*\{[^}]*)\}',
                    r'\1\n        classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.10"\n    }',
                    content,
                    count=1
                )
        
        print(f'ROOT Content changed: {content != original_content}', flush=True)
        if content != original_content:
            with open(root_build_gradle, 'w') as f:
                f.write(content)
            print(f'UPDATED ROOT: {root_build_gradle}', flush=True)
        else:
            print(f'NO CHANGE NEEDED ROOT: {root_build_gradle}', flush=True)
        
        # Verify
        with open(root_build_gradle, 'r') as f:
            new_content = f.read()
        print(f'ROOT New content: {new_content}', flush=True)
        if 'kotlin_version = "1.9.10"' in new_content:
            print('SUCCESS: kotlin_version is now 1.9.10 in root build.gradle', flush=True)
        else:
            print('WARNING: kotlin_version may not have been updated correctly in root', flush=True)
    else:
        print(f'NOT FOUND ROOT: {root_build_gradle}', flush=True)
        # List what's in the project dir
        android_dir = os.path.join(project_dir, 'android')
        if os.path.exists(android_dir):
            print(f'Contents of {android_dir}: {os.listdir(android_dir)}', flush=True)
        else:
            print(f'android dir does not exist: {android_dir}', flush=True)
    
    # Fix APP build.gradle (app level) - change plugins DSL to apply plugin for kotlin-android
    app_build_gradle = os.path.join(project_dir, 'android', 'app', 'build.gradle')
    print(f'Looking for APP: {app_build_gradle}', flush=True)
    print(f'APP Exists: {os.path.exists(app_build_gradle)}', flush=True)
    
    if os.path.exists(app_build_gradle):
        with open(app_build_gradle, 'r') as f:
            content = f.read()
        
        print(f'APP Processing: {app_build_gradle}', flush=True)
        print(f'APP Content length: {len(content)}', flush=True)
        
        original_content = content
        
        # Remove id "kotlin-android" from plugins block
        # This regex matches the line with id "kotlin-android" or id 'kotlin-android'
        content = re.sub(
            r'\n\s*id\s+[\'"]kotlin-android[\'"]\s*',
            '',
            content
        )
        
        # Add apply plugin: "kotlin-android" after the plugins block
        # Find the end of the plugins block
        content = re.sub(
            r'(plugins\s*\{[^}]*\})',
            r'\1\n\napply plugin: "kotlin-android"',
            content,
            count=1
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
            print(f'UPDATED APP: {app_build_gradle}', flush=True)
        else:
            print(f'NO CHANGE NEEDED APP: {app_build_gradle}', flush=True)
        
        # Verify
        with open(app_build_gradle, 'r') as f:
            new_content = f.read()
        if 'apply plugin: "kotlin-android"' in new_content:
            print('SUCCESS: apply plugin: "kotlin-android" added in app build.gradle', flush=True)
        else:
            print('WARNING: apply plugin: "kotlin-android" may not have been added correctly', flush=True)
            for m in re.finditer(r'apply plugin', new_content):
                print(f'Found "apply plugin" at position {m.start()}: ...{new_content[max(0,m.start()-50):m.end()+50]}...', flush=True)
    else:
        print(f'NOT FOUND APP: {app_build_gradle}', flush=True)
    
    # Fix settings.gradle
    settings_gradle = os.path.join(project_dir, 'android', 'settings.gradle')
    print(f'Looking for SETTINGS: {settings_gradle}', flush=True)
    print(f'SETTINGS Exists: {os.path.exists(settings_gradle)}', flush=True)
    
    if os.path.exists(settings_gradle):
        with open(settings_gradle, 'r') as f:
            content = f.read()
        
        print(f'SETTINGS Processing: {settings_gradle}', flush=True)
        
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
            print(f'UPDATED SETTINGS: {settings_gradle}', flush=True)
        else:
            print(f'NO CHANGE NEEDED SETTINGS: {settings_gradle}', flush=True)
    else:
        print(f'NOT FOUND SETTINGS: {settings_gradle}', flush=True)

if __name__ == '__main__':
    # Use absolute path from GITHUB_WORKSPACE if available
    github_workspace = os.environ.get('GITHUB_WORKSPACE', '.')
    print(f'GITHUB_WORKSPACE: {github_workspace}', flush=True)
    
    projects = ['customer_new', 'vendor_new', 'rider_new']
    for project in projects:
        full_path = os.path.join(github_workspace, project)
        fix_kotlin_version(full_path)
    
    print('\n=== Done ===', flush=True)