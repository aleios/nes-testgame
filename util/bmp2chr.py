from PIL import Image
import sys

# TODO: Disregard all this crap, just let it do its thing.
CHR_ROM_SIZE = 8192  # 8KB for NES CHR ROM
TILE_SIZE = 16       # Each tile is 16 bytes (8x8 pixels, 2 bpp)
PAGE_SIZE = 4096     # Each page is 4KB

def bmp_to_chr(img, split_vertical=True):
    img = img.convert('P')  # Ensure image is in indexed mode
    width, height = img.size

    # Sanity check for image size.
    if width % 8 != 0 or height % 8 != 0:
        raise ValueError("dimension must be a multiple of 8")

    chr_data = bytearray()

    # Iterate over each 8x8 tile
    for tile_y in range(0, height, 8):
        for tile_x in range(0, width, 8):
            # Adjust tile_x and tile_y based on split mode
            if not split_vertical:
                # For horizontal split, adjust x coordinate to handle left/right split
                if tile_x >= width // 2:
                    tile_x = tile_x - width // 2 + width // 2 * (tile_y // 8)
                    tile_y = 0

            # Extract two bitplanes for each tile
            for plane in range(2):
                for row in range(8):
                    byte = 0
                    for col in range(8):
                        pixel = img.getpixel((tile_x + col, tile_y + row))
                        if plane == 0:
                            bit = pixel & 0x01  # LSB
                        else:
                            bit = (pixel >> 1) & 0x01  # MSB
                        byte |= (bit << (7 - col))  # Move the bit
                    chr_data.append(byte)

    return chr_data

def save_chr(chr_data, output_path):
    # Make sure this is a 8KB bank. TODO: Maybe support 4KB banks...
    if len(chr_data) < CHR_ROM_SIZE:
        chr_data.extend([0] * (CHR_ROM_SIZE - len(chr_data)))
    elif len(chr_data) > CHR_ROM_SIZE:
        raise ValueError("CHR data exceeds 8KB")

    with open(output_path, 'wb') as f:
        f.write(chr_data)

def main():
    if len(sys.argv) < 3:
        print("Usage: python bmp_to_chr.py <output.chr> <bmp_file1> [<bmp_file2>]")
        return

    output_path = sys.argv[1]
    bmp_file1 = sys.argv[2]
    bmp_file2 = sys.argv[3] if len(sys.argv) > 3 else None

    if bmp_file2:
        # Two image mode. Use bmp_file1 for sprites and bmp_file2 for backgrounds
        sprite_chr = bmp_to_chr(Image.open(bmp_file1))[:PAGE_SIZE]
        background_chr = bmp_to_chr(Image.open(bmp_file2))[:PAGE_SIZE]
        chr_data = sprite_chr + background_chr
    else:
        # Single image mode. Determine if its been horizontal or vertical laid out.
        img = Image.open(bmp_file1)
        width, height = img.size

        if width == 128 and height == 256:
            split_vertical = True  # Split into top and bottom halves
        elif width == 256 and height == 128:
            split_vertical = False  # Split into left and right halves
        else:
            raise ValueError("Image size must be either 128x256 or 256x128 for single image mode.")

        single_image_chr = bmp_to_chr(img, split_vertical=split_vertical)
        sprite_chr, background_chr = single_image_chr[:PAGE_SIZE], single_image_chr[PAGE_SIZE:]
        chr_data = sprite_chr + background_chr

    save_chr(chr_data, output_path)
    print(f"CHR-ROM saved to {output_path}")

main()
