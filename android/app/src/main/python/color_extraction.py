import hashlib
import random

def extract_dominant_color(image_path):
    """
    Simplified color extraction that generates colors based on image path hash.
    This is a demo implementation that doesn't require heavy dependencies.
    In production, you would use actual image processing libraries.
    """
    try:
        # Generate a consistent color based on image path hash
        hash_object = hashlib.md5(image_path.encode())
        hash_hex = hash_object.hexdigest()
        
        # Extract RGB values from hash
        r = int(hash_hex[0:2], 16)
        g = int(hash_hex[2:4], 16) 
        b = int(hash_hex[4:6], 16)
        
        # Adjust colors to be more visually appealing
        r = max(50, min(200, r))  # Keep in reasonable range
        g = max(50, min(200, g))
        b = max(50, min(200, b))
        
        # Convert RGB to HEX
        return '#{:02x}{:02x}{:02x}'.format(r, g, b)
    except Exception as e:
        print(f"Error: {e}")
        return '#4B5563'  # Fallback color

def extract_color_palette(image_path, color_count=5):
    """
    Generate a color palette based on the dominant color.
    This creates variations of the main color for a cohesive palette.
    """
    try:
        # Get the base color
        base_color_hex = extract_dominant_color(image_path)
        base_color_hex = base_color_hex.replace('#', '')
        
        # Convert to RGB
        r = int(base_color_hex[0:2], 16)
        g = int(base_color_hex[2:4], 16)
        b = int(base_color_hex[4:6], 16)
        
        # Generate palette variations
        palette = []
        palette.append(f'#{base_color_hex}')  # Original color
        
        # Generate lighter and darker variations
        for i in range(1, color_count):
            # Create variations by adjusting brightness
            factor = 0.7 + (i * 0.1)  # Vary from 0.7 to 1.1+
            
            new_r = max(0, min(255, int(r * factor)))
            new_g = max(0, min(255, int(g * factor)))
            new_b = max(0, min(255, int(b * factor)))
            
            palette.append('#{:02x}{:02x}{:02x}'.format(new_r, new_g, new_b))
        
        return palette[:color_count]
    except Exception as e:
        print(f"Error: {e}")
        return ['#4B5563', '#6B7280', '#9CA3AF', '#D1D5DB', '#F3F4F6']  # Fallback palette

def get_demo_message():
    """
    Returns a message explaining this is a demo implementation.
    """
    return "Demo: Colors generated from image path hash. For production, use actual image processing."