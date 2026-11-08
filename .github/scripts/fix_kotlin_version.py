import re
import sys
import os

def fix_kotlin_version(project_dir):
    """Fix Kotlin version in a Flutter project's Gradle files (Groovy DSL .gradle)."""
    print(f'\n=== Fixing Kotlin version for {project_dir} ===', flush=True)
    print(f'Current working directory: {os.getcwd()}', flush=True)
    print(f'Project dir absolute: {os.path.abspath(project_dir)}', flush=True)
    print(f'Project dir exists: {os.path.exists(project_dir)}', flush=True)
    
    # Use Kotlin 1.9.10 with AGP 8.1.0 - matches stdlib 1.9.25
    KOTLIN_VERSION = '1.9.10'
    AGP_VERSION = '8.1.0'
    
    # Fix ROOT build.gradle (project level) - add buildscript block
    root_build_gradle = os.path.join(project_dir, 'android', 'build.gradle')
    print(f'Looking for ROOT: {root_build_gradle}', flush=True)
    print(f'ROOT Exists: {os.path.exists(root_build_gradle)}', flush=True)
    
    if os.path.exists(root_build_gradle):
        with open(root_build_gradle, 'r') as f:
            content = f.read()
        
        print(f'ROOT Original content length: {len(content)}', flush=True)
        print(f'ROOT Original content: {content}', flush=True)
        
        # Check if buildscript already exists
        if 'buildscript {' in content:
            print('ROOT: buildscript block already exists', flush=True)
            # Update kotlin_version in existing buildscript
            content = re.sub(
                r'(ext\.kotlin_version\s*=\s*)[\'"][^\'"]*[\'"]',
                rf'\1"{KOTLIN_VERSION}"',
                content
            )
            # Update classpath
            content = re.sub(
                r'classpath\s+[\'"]org\.jetbrains\.kotlin:kotlin-gradle-plugin:[0-9]+\.[0-9]+\.[0-9]+[\'"]',
                f'classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:{KOTLIN_VERSION}"',
                content
            )
            print('ROOT: Updated existing buildscript block', flush=True)
        else:
            # Add buildscript block at the beginning
            buildscript_block = f'''buildscript {{
    ext.kotlin_version = '{KOTLIN_VERSION}'
    repositories {{
        google()
        mavenCentral()
    }}
    dependencies {{
        classpath 'com.android.tools.build:gradle:{AGP_VERSION}'
        classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:{KOTLIN_VERSION}"
    }}
}}

'''
            content = buildscript_block + content
            print('ROOT: Added buildscript block with Kotlin 1.9.10', flush=True)
        
        with open(root_build_gradle, 'w') as f:
            f.write(content)
        print(f'UPDATED ROOT: {root_build_gradle}', flush=True)
        
        # Verify
        print(f'ROOT New content: {content}', flush=True)
        print(f'SUCCESS: Root build.gradle updated with Kotlin {KOTLIN_VERSION} and AGP {AGP_VERSION}', flush=True)
    else:
        print(f'NOT FOUND ROOT: {root_build_gradle}', flush=True)
        android_dir = os.path.join(project_dir, 'android')
        if os.path.exists(android_dir):
            print(f'Contents of {android_dir}: {os.listdir(android_dir)}', flush=True)
        else:
            print(f'android dir does not exist: {android_dir}', flush=True)
    
    # Fix APP build.gradle (app level) - add kotlin-android plugin with explicit version
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
        content = re.sub(
            r'\n\s*id\s+[\'"]kotlin-android[\'"]\s*',
            '',
            content
        )
        
        # Add apply plugin: "kotlin-android" after the plugins block with version
        content = re.sub(
            r'(plugins\s*\{[^}]*\})',
            f'\\1\n\napply plugin: "kotlin-android"\next.kotlin_version = "{KOTLIN_VERSION}"',
            content,
            count=1
        )
        
        # Also handle classpath in buildscript dependencies
        content = re.sub(
            r'classpath\s+[\'"]org\.jetbrains\.kotlin:kotlin-gradle-plugin:[0-9]+\.[0-9]+\.[0-9]+[\'"]',
            f'classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:{KOTLIN_VERSION}"',
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
        
        original_content = content
        content = re.sub(
            r'classpath\s+[\'"]org\.jetbrains\.kotlin:kotlin-gradle-plugin:[0-9]+\.[0-9]+\.[0-9]+[\'"]',
            f'classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:{KOTLIN_VERSION}"',
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
    github_workspace = os.environ.get('GITHUB_WORKSPACE', '.')
    print(f'GITHUB_WORKSPACE: {github_workspace}', flush=True)
    
    projects = ['customer_new', 'vendor_new', 'rider_new']
    for project in projects:
        full_path = os.path.join(github_workspace, project)
        fix_kotlin_version(full_path)
    
    print('\n=== Done ===', flush=True)