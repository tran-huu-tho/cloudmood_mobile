import os
import re

dynamic_keys = [
    'AppTheme.background', 'AppTheme.surface', 'AppTheme.surfaceVariant',
    'AppTheme.primaryContainer', 'AppTheme.darkText', 'AppTheme.bodyText',
    'AppTheme.subtitleText', 'AppTheme.hintText', 'AppTheme.border',
    'AppTheme.divider', 'AppTheme.primaryPeach', 'AppTheme.lightGray',
    'AppTheme.brandLogoStyle', 'AppTheme.screenTitleStyle', 'AppTheme.sectionTitleStyle',
    'AppTheme.bodyBoldStyle', 'AppTheme.bodyMediumStyle', 'AppTheme.captionStyle',
    'AppTheme.labelStyle'
]

def find_matching_paren(s, start_idx):
    count = 0
    in_single_quote = False
    in_double_quote = False
    escape = False
    
    i = start_idx
    while i < len(s):
        char = s[i]
        
        if escape:
            escape = False
            i += 1
            continue
            
        if char == '\\':
            escape = True
            i += 1
            continue
            
        if char == "'" and not in_double_quote:
            in_single_quote = not in_single_quote
            i += 1
            continue
            
        if char == '"' and not in_single_quote:
            in_double_quote = not in_double_quote
            i += 1
            continue
            
        if not in_single_quote and not in_double_quote:
            if char == '(':
                count += 1
            elif char == ')':
                count -= 1
                if count == 0:
                    return i
        i += 1
    return -1

def strip_const_from_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    modified = False
    pattern = re.compile(r'\bconst\s+([A-Za-z0-9_.]+)\s*\(')
    
    pos = 0
    while True:
        match = pattern.search(content, pos)
        if not match:
            break
            
        const_start = match.start()
        paren_start = match.end() - 1 # index of '('
        
        paren_end = find_matching_paren(content, paren_start)
        if paren_end == -1:
            pos = match.end()
            continue
            
        body = content[paren_start:paren_end+1]
        
        # Check if the body contains any dynamic AppTheme field
        if any(key in body for key in dynamic_keys):
            # Strip "const " from the file content at const_start
            prefix = content[:const_start]
            suffix = content[const_start + 6:] # length of "const " is 6
            content = prefix + suffix
            modified = True
            # Restart search from const_start
            pos = const_start
        else:
            pos = paren_end
            
    if modified:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Fixed: {filepath}")

# Process all .dart files in lib/
lib_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'lib')
for root, dirs, files in os.walk(lib_dir):
    for file in files:
        if file.endswith('.dart'):
            strip_const_from_file(os.path.join(root, file))

print("Done cleaning const modifiers!")
