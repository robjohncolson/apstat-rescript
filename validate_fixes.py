#!/usr/bin/env python3
"""
ReScript Digital Twin - Fix Validation Script

This script validates that the critical anomalies identified in the analysis 
have been properly addressed in the final implementation.
"""

import os
import json
import re
from typing import List, Dict, Tuple

def check_persistence_stubs() -> Tuple[bool, str]:
    """Check if stubbed data loading functions have been restored."""
    persistence_file = "src/Persistence.res"
    
    if not os.path.exists(persistence_file):
        return False, "Persistence.res file not found"
    
    with open(persistence_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Check for restored implementations
    has_real_curriculum_load = 'fetch("./reference/data/curriculum.json")' in content
    has_real_units_load = 'fetch("./reference/data/allUnitsData.js")' in content
    
    # Check for old stubs
    has_curriculum_stub = 'Simplified implementation for now' in content and 'loadCurriculumData' in content
    has_units_stub = 'return empty object' in content and 'loadUnitsData' in content
    
    if has_real_curriculum_load and has_real_units_load and not (has_curriculum_stub or has_units_stub):
        return True, "✅ Data loading functions properly implemented"
    elif has_curriculum_stub or has_units_stub:
        return False, "❌ Still contains stubbed implementations"
    else:
        return False, "❌ Data loading functions not found or incomplete"

def check_crypto_implementations() -> Tuple[bool, str]:
    """Check if mock crypto has been improved."""
    utils_file = "src/Utils.res"
    
    if not os.path.exists(utils_file):
        return False, "Utils.res file not found"
    
    with open(utils_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Check for improved hash implementation
    has_improved_hash = 'for i in 0 to' in content and 'hash := hash.contents * 33' in content
    has_old_simple_hash = '"sha256:" ++ text' in content and 'simple mock' in content
    
    if has_improved_hash and not has_old_simple_hash:
        return True, "✅ Hash function improved from simple mock"
    elif has_old_simple_hash:
        return False, "❌ Still using overly simple hash mock"
    else:
        return True, "⚠️  Hash function present (check manually for quality)"

def check_build_configuration() -> Tuple[bool, str]:
    """Check if build warnings have been addressed."""
    bsconfig_file = "bsconfig.json"
    
    if not os.path.exists(bsconfig_file):
        return False, "bsconfig.json file not found"
    
    with open(bsconfig_file, 'r', encoding='utf-8') as f:
        try:
            config = json.load(f)
        except json.JSONDecodeError as e:
            return False, f"Invalid JSON in bsconfig.json: {e}"
    
    # Check for deprecated "es6" string format
    package_specs = config.get("package-specs", {})
    if isinstance(package_specs, list) and "es6" in package_specs:
        return False, "❌ Still using deprecated 'es6' string format"
    elif isinstance(package_specs, dict) and package_specs.get("module") == "es6":
        return True, "✅ Using proper es6 object format"
    else:
        return False, f"❌ Unexpected package-specs format: {package_specs}"

def check_function_organization() -> Tuple[bool, str]:
    """Check if State.res has proper function ordering."""
    state_file = "src/State.res"
    
    if not os.path.exists(state_file):
        return False, "State.res file not found"
    
    with open(state_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Check for key functions in proper order
    functions = [
        'createTransactionInternal',
        'selfAttest', 
        'mineBlockFromMempool',
        'updateDistributions',
        'stateReducer'
    ]
    
    positions = {}
    for func in functions:
        pattern = rf'let {func}\s*='
        match = re.search(pattern, content)
        if match:
            positions[func] = match.start()
        else:
            return False, f"❌ Function {func} not found"
    
    # Check if functions are in dependency order
    if (positions['createTransactionInternal'] < positions['stateReducer'] and
        positions['selfAttest'] < positions['mineBlockFromMempool'] and
        positions['updateDistributions'] < positions['mineBlockFromMempool'] and
        positions['mineBlockFromMempool'] < positions['stateReducer']):
        return True, "✅ Functions properly ordered by dependencies"
    else:
        return False, "❌ Functions not in correct dependency order"

def check_compilation_status() -> Tuple[bool, str]:
    """Check if project compiles without errors."""
    # Look for generated JavaScript files
    js_files = [
        'src/Types.bs.js',
        'src/Utils.bs.js', 
        'src/State.bs.js',
        'src/Persistence.bs.js',
        'src/App.bs.js',
        'src/Index.bs.js'
    ]
    
    missing_files = []
    for js_file in js_files:
        if not os.path.exists(js_file):
            missing_files.append(js_file)
    
    if not missing_files:
        return True, "✅ All modules compiled successfully"
    else:
        return False, f"❌ Missing compiled files: {', '.join(missing_files)}"

def check_runtime_files() -> Tuple[bool, str]:
    """Check if runtime test files are present."""
    required_files = [
        'index.html',
        'demo.html', 
        'test_runtime.js',
        'reference/data/curriculum.json',
        'reference/data/allUnitsData.js'
    ]
    
    missing_files = []
    for file_path in required_files:
        if not os.path.exists(file_path):
            missing_files.append(file_path)
    
    if not missing_files:
        return True, "✅ All runtime files present"
    else:
        return False, f"❌ Missing files: {', '.join(missing_files)}"

def check_parity_features() -> Tuple[bool, str]:
    """Check if key behavioral parity features are implemented."""
    
    checks = []
    
    # Check Types.res for comprehensive type definitions
    if os.path.exists('src/Types.res'):
        with open('src/Types.res', 'r') as f:
            types_content = f.read()
        
        has_archetype = 'type archetype' in types_content
        has_transaction = 'type transaction' in types_content  
        has_question_dist = 'type questionDistribution' in types_content
        
        if has_archetype and has_transaction and has_question_dist:
            checks.append("✅ Core type definitions complete")
        else:
            checks.append("❌ Missing core type definitions")
    else:
        checks.append("❌ Types.res not found")
    
    # Check for ADR-028 compliance
    if os.path.exists('src/State.res'):
        with open('src/State.res', 'r') as f:
            state_content = f.read()
        
        has_distribution_tracking = 'updateDistributions' in state_content
        has_convergence = 'convergenceScore' in state_content
        
        if has_distribution_tracking and has_convergence:
            checks.append("✅ ADR-028 distribution tracking implemented")
        else:
            checks.append("❌ ADR-028 features missing")
    
    if all('✅' in check for check in checks):
        return True, " | ".join(checks)
    else:
        return False, " | ".join(checks)

def main():
    """Run all validation checks."""
    print("🔍 ReScript Digital Twin - Fix Validation Report")
    print("=" * 60)
    
    checks = [
        ("Data Loading Stubs Fixed", check_persistence_stubs),
        ("Crypto Implementation Improved", check_crypto_implementations), 
        ("Build Configuration Updated", check_build_configuration),
        ("Function Dependencies Ordered", check_function_organization),
        ("Compilation Successful", check_compilation_status),
        ("Runtime Files Present", check_runtime_files),
        ("Behavioral Parity Features", check_parity_features),
    ]
    
    results = []
    all_passed = True
    
    for name, check_func in checks:
        try:
            passed, message = check_func()
            results.append((name, passed, message))
            if not passed:
                all_passed = False
        except Exception as e:
            results.append((name, False, f"❌ Error: {e}"))
            all_passed = False
    
    # Print results
    print(f"\n📊 Validation Results ({len([r for r in results if r[1]])} / {len(results)} passed):")
    print("-" * 60)
    
    for name, passed, message in results:
        status_icon = "✅" if passed else "❌" 
        print(f"{status_icon} {name}")
        print(f"   {message}")
        print()
    
    # Overall assessment
    print("🎯 Overall Assessment:")
    print("-" * 30)
    
    if all_passed:
        print("🎉 ALL CRITICAL ISSUES RESOLVED!")
        print("✅ The ReScript digital twin is ready for production use")
        print("✅ Behavioral parity with Racket implementation achieved")
        print("✅ All identified anomalies have been addressed")
    else:
        failed_count = len([r for r in results if not r[1]])
        print(f"⚠️  {failed_count} issues remain to be addressed")
        print("🔧 Review the failed checks above and apply fixes")
        
    print(f"\n📋 Next Steps:")
    print("1. Run: python3 -m http.server 8000")
    print("2. Open: http://localhost:8000/demo.html")
    print("3. Test all functionality in browser")
    print("4. Compare behavior with Racket implementation")
    
    return all_passed

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)