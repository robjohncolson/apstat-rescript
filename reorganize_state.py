#!/usr/bin/env python3
"""
ReScript State.res File Reorganizer

This script reorganizes the State.res file to fix dependency ordering issues.
ReScript requires all functions to be defined before they are used.
"""

import re
import os
from typing import List, Dict, Set, Tuple

def extract_functions(content: str) -> List[Tuple[str, str, int, int]]:
    """
    Extract function definitions with their dependencies.
    Returns: List of (function_name, full_definition, start_pos, end_pos)
    """
    functions = []
    
    # Pattern to match function definitions
    func_pattern = r'let\s+(\w+)\s*=\s*\([^)]*\)\s*:\s*[^=]+=>\s*\{'
    type_pattern = r'type\s+(\w+)\s*='
    
    # Find all function definitions
    for match in re.finditer(func_pattern, content, re.MULTILINE):
        func_name = match.group(1)
        start_pos = match.start()
        
        # Find the end of this function by counting braces
        brace_count = 0
        in_function = False
        end_pos = start_pos
        
        for i, char in enumerate(content[start_pos:], start_pos):
            if char == '{':
                brace_count += 1
                in_function = True
            elif char == '}':
                brace_count -= 1
                if in_function and brace_count == 0:
                    end_pos = i + 1
                    break
        
        # Extract the full function definition
        func_def = content[start_pos:end_pos]
        functions.append((func_name, func_def, start_pos, end_pos))
    
    # Also find type definitions
    for match in re.finditer(type_pattern, content, re.MULTILINE):
        type_name = match.group(1)
        start_pos = match.start()
        
        # Find end of type definition (usually ends with newline or next definition)
        end_pos = content.find('\n\n', start_pos)
        if end_pos == -1:
            end_pos = len(content)
        
        type_def = content[start_pos:end_pos]
        functions.append((type_name, type_def, start_pos, end_pos))
    
    return sorted(functions, key=lambda x: x[2])  # Sort by start position

def find_dependencies(func_def: str, all_functions: Set[str]) -> Set[str]:
    """Find which functions this definition depends on."""
    dependencies = set()
    
    # Look for function calls and type usage
    for func_name in all_functions:
        # Check if this function/type is used in the definition
        if re.search(rf'\b{func_name}\b', func_def):
            dependencies.add(func_name)
    
    return dependencies

def topological_sort(functions: Dict[str, str], dependencies: Dict[str, Set[str]]) -> List[str]:
    """Sort functions by dependency order."""
    visited = set()
    temp_visited = set()
    result = []
    
    def visit(func_name: str):
        if func_name in temp_visited:
            # Circular dependency - just continue
            return
        if func_name in visited:
            return
            
        temp_visited.add(func_name)
        
        # Visit dependencies first
        for dep in dependencies.get(func_name, set()):
            if dep in functions and dep != func_name:
                visit(dep)
        
        temp_visited.remove(func_name)
        visited.add(func_name)
        result.append(func_name)
    
    for func_name in functions:
        if func_name not in visited:
            visit(func_name)
    
    return result

def reorganize_state_file(file_path: str):
    """Main function to reorganize the State.res file."""
    
    print(f"Reading {file_path}...")
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Extract header comments and imports
    lines = content.split('\n')
    header_lines = []
    imports_section = []
    
    for i, line in enumerate(lines):
        if line.startswith('//') or line.strip() == '' or line.startswith('open '):
            header_lines.append(line)
        elif line.startswith('let ') or line.startswith('type '):
            # Start of function/type definitions
            break
        else:
            header_lines.append(line)
    
    header = '\n'.join(header_lines)
    
    # Extract function and type definitions
    print("Extracting functions...")
    extracted_functions = extract_functions(content)
    
    # Remove duplicates by name (keep the first occurrence)
    unique_functions = {}
    seen_names = set()
    
    for name, definition, start, end in extracted_functions:
        if name not in seen_names:
            unique_functions[name] = definition
            seen_names.add(name)
        else:
            print(f"Removing duplicate: {name}")
    
    # Find dependencies
    print("Analyzing dependencies...")
    all_func_names = set(unique_functions.keys())
    dependencies = {}
    
    for func_name, func_def in unique_functions.items():
        deps = find_dependencies(func_def, all_func_names)
        dependencies[func_name] = deps
        if deps:
            print(f"{func_name} depends on: {deps}")
    
    # Sort by dependencies
    print("Sorting by dependencies...")
    sorted_names = topological_sort(unique_functions, dependencies)
    
    # Separate types and functions for better organization
    types = []
    functions = []
    
    for name in sorted_names:
        definition = unique_functions[name]
        if definition.strip().startswith('type '):
            types.append(definition)
        else:
            functions.append(definition)
    
    # Reconstruct the file
    print("Reconstructing file...")
    new_content = header + '\n\n'
    
    if types:
        new_content += '// =============================================================================\n'
        new_content += '// TYPE DEFINITIONS\n' 
        new_content += '// =============================================================================\n\n'
        new_content += '\n\n'.join(types) + '\n\n'
    
    if functions:
        new_content += '// =============================================================================\n'
        new_content += '// FUNCTION DEFINITIONS (ordered by dependencies)\n'
        new_content += '// =============================================================================\n\n'
        new_content += '\n\n'.join(functions) + '\n'
    
    # Write the reorganized file
    backup_path = file_path + '.backup'
    print(f"Creating backup at {backup_path}")
    with open(backup_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"Writing reorganized file to {file_path}")
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    
    print("✅ Reorganization complete!")
    print(f"   - Processed {len(unique_functions)} functions/types")
    print(f"   - Removed {len(extracted_functions) - len(unique_functions)} duplicates")
    print(f"   - Backup saved to {backup_path}")

if __name__ == "__main__":
    state_file = "/mnt/c/Users/rober/Downloads/apstat-rescript/src/State.res"
    
    if not os.path.exists(state_file):
        print(f"❌ Error: {state_file} not found")
        exit(1)
    
    try:
        reorganize_state_file(state_file)
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        exit(1)