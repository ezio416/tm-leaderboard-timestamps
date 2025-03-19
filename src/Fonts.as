// c 2023-08-16
// m 2025-03-19

nvg::Font font;
Font currentFont = S_Font;

enum Font {
    // DroidSans,
    DroidSansBold,
    DroidSansMono,
    _Count
}

void ChangeFont() {
    int f = -1;

    switch (S_Font) {
        // case Font::DroidSans:     f = nvg::LoadFont("DroidSans.ttf");      break;
        case Font::DroidSansBold: f = nvg::LoadFont("DroidSans-Bold.ttf"); break;
        case Font::DroidSansMono: f = nvg::LoadFont("DroidSansMono.ttf");  break;
        default:;
    }

    if (f > 1)
        font = f;

    currentFont = S_Font;
}
