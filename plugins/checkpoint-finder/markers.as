// What the player sees for each checkpoint: a small glowing ball on it in the world, and a dot over it on the screen
// that walls never hide, bigger the closer it is. The nearest untouched one says how far it is. Touched ones are grey
// and faint. Settled in-game on the prototype branch claude/prototype-checkpoint-finder (rounds E, E3 and T1).

const double kBallRadius = 60;
const float kBallGlow = 8;
const float kTouchedGlow = 1;
const float kDotLargest = 44;          // px, at the checkpoint
const float kDotSmallest = 12;         // px, from 128 m away
const double kShrinkPerPixel = 400;    // cm farther for each pixel smaller
const float kDotStep = 4;             // px: sizes come in steps, since restyling a dot rebuilds its window
const float kEdge = 24;                // dots off the screen stay this far inside its edge
const float kLabelWidth = 60;
const float kLabelHeight = 20;
const float kLabelGap = 4;
const float kTouchedGrey = 0.45f;
const float kTouchedOpacity = 0.4f;

// One colour per checkpoint, cycling, so neighbours tell apart.
const array<float> kPalette = {
    1.0f, 0.35f, 0.25f,   0.25f, 0.8f, 1.0f,   1.0f, 0.85f, 0.2f,   0.5f, 1.0f, 0.35f,
    0.85f, 0.4f, 1.0f,    1.0f, 0.55f, 0.15f,  0.2f, 1.0f, 0.8f,    1.0f, 0.45f, 0.75f
};

class Dot
{
    private UI::Window@ circle;     // a window whose corner radius is half its size
    private UI::Window@ label;
    private UI::Text@ labelText;
    // What the circle and label were last given: restyling a window rebuilds it, so it only happens on a change.
    private float styledSize = -1;
    private array<float> circleColour = {-1, -1, -1, -1};
    private array<float> labelColour = {-1, -1, -1};

    Dot()
    {
        @circle = Bare();
        @label = Bare();
        label.SetBackground(0, 0, 0, 0.55f);
        label.SetCornerRadius(6);
        label.SetPadding(6, 1);
        @labelText = label.AddText("", 13);
    }

    // The circle, centred on a point of the screen. Moving it doesn't rebuild the window; a new size or colour does.
    void Place(float sx, float sy, float size, float r, float g, float b, float a)
    {
        if (size != styledSize || r != circleColour[0] || g != circleColour[1] || b != circleColour[2] || a != circleColour[3])
        {
            styledSize = size;
            circleColour = {r, g, b, a};
            circle.SetBackground(r, g, b, a);
            circle.SetCornerRadius(size / 2);
        }
        circle.SetRect(sx - size / 2, sy - size / 2, size, size);
        circle.visible = true;
    }

    // A label under the circle (over it at the bottom of the screen), kept on screen.
    void Label(const string &in text, float sx, float sy, float size, float r, float g, float b, float w, float h)
    {
        labelText.text = text;
        if (r != labelColour[0] || g != labelColour[1] || b != labelColour[2])
        {
            labelColour = {r, g, b};
            labelText.SetColor(r, g, b, 1);
        }
        float y = sy + size / 2 + kLabelGap;
        if (y + kLabelHeight > h)
            y = sy - size / 2 - kLabelGap - kLabelHeight;
        float x = Clamp(sx - kLabelWidth / 2, 0, w - kLabelWidth);
        label.SetRect(x, y, kLabelWidth, kLabelHeight);
        label.visible = true;
    }

    void HideLabel() { label.visible = false; }

    void Hide()
    {
        circle.visible = false;
        label.visible = false;
    }

    private UI::Window@ Bare()
    {
        UI::Window@ w = UI::CreateWindow();
        w.SetPadding(0, 0);
        w.SetBlocksClicks(false);
        w.zOrder = 60;
        w.visible = false;
        return w;
    }
}

class Markers
{
    private array<int> balls;
    private array<bool> ballTouched;
    private array<Dot@> dots;           // windows can't be removed, so they're kept for the next map
    private int builtFor = -1;          // the Checkpoints generation the balls were made for

    // Call every frame while shown on a track.
    void Show(const Checkpoints@ cps)
    {
        // A new list, or the host cleared the shapes (it does on a map change and when the game makes a new player
        // controller): make them again. Show is false for a shape that's gone.
        if (builtFor != cps.generation || !BallsAlive())
            MakeBalls(cps);
        for (uint k = 0; k < balls.length(); k++)
            if (balls[k] != 0 && cps.touched[k] != ballTouched[k])
            {
                ballTouched[k] = cps.touched[k];
                float r, g, b;
                Colour(k, cps.touched[k], r, g, b);
                Draw::Glow(balls[k], r, g, b, ballTouched[k] ? kTouchedGlow : kBallGlow);
            }
        PlaceDots(cps);
    }

    // Hidden, or off a track: nothing on screen.
    void Hide()
    {
        for (uint k = 0; k < balls.length(); k++)
            Draw::Remove(balls[k]);
        balls.resize(0);
        ballTouched.resize(0);
        builtFor = -1;
        for (uint k = 0; k < dots.length(); k++)
            dots[k].Hide();
    }

    // False once the host has cleared the shapes. Show answers false for a shape that's gone; one ball stands for all,
    // since the host clears them together. A ball the host couldn't make (id 0) is never asked about.
    private bool BallsAlive()
    {
        for (uint k = 0; k < balls.length(); k++)
            if (balls[k] != 0)
                return Draw::Show(balls[k], true);
        return true;
    }

    private void MakeBalls(const Checkpoints@ cps)
    {
        Hide();
        builtFor = cps.generation;
        for (uint k = 0; k < cps.count; k++)
        {
            int ball = 0;
            if (cps.placed[k])
            {
                float r, g, b;
                Colour(k, cps.touched[k], r, g, b);
                ball = Draw::Ball(kBallRadius, r, g, b, true);
                Draw::Move(ball, cps.x[k], cps.y[k], cps.z[k]);
            }
            balls.insertLast(ball);
            ballTouched.insertLast(false);
        }
    }

    private void PlaceDots(const Checkpoints@ cps)
    {
        float w, h;
        if (!UI::ScreenSize(w, h))
            return;
        while (dots.length() < cps.count)
            dots.insertLast(Dot());

        double bx, by, bz;
        bool ball = Race::BallPosition(bx, by, bz);
        int nearest = ball ? cps.NearestUntouched(bx, by, bz) : -1;

        for (uint k = 0; k < dots.length(); k++)
        {
            Dot@ dot = dots[k];
            float sx = 0, sy = 0;
            if (k >= cps.count || !cps.placed[k] || !Camera::Project(cps.x[k], cps.y[k], cps.z[k], sx, sy))
            {
                dot.Hide();     // behind the camera
                continue;
            }
            sx = Clamp(sx, kEdge, w - kEdge);
            sy = Clamp(sy, kEdge, h - kEdge);
            double d = ball ? Math::sqrt(cps.DistanceSquared(k, bx, by, bz)) : 0;
            float size = Clamp(kDotLargest - float(d / kShrinkPerPixel), kDotSmallest, kDotLargest);
            size = kDotSmallest + Math::floor((size - kDotSmallest) / kDotStep + 0.5) * kDotStep;
            float r, g, b;
            Colour(k, cps.touched[k], r, g, b);
            dot.Place(sx, sy, size, r, g, b, cps.touched[k] ? kTouchedOpacity : 1);
            if (int(k) == nearest)
                dot.Label(int(d / 100) + " m", sx, sy, size, r, g, b, w, h);
            else
                dot.HideLabel();
        }
    }
}

void Colour(uint k, bool touched, float &out r, float &out g, float &out b)
{
    if (touched)
    {
        r = g = b = kTouchedGrey;
        return;
    }
    uint c = k % (kPalette.length() / 3);
    r = kPalette[c * 3];
    g = kPalette[c * 3 + 1];
    b = kPalette[c * 3 + 2];
}

float Clamp(float v, float lo, float hi) { return v < lo ? lo : v > hi ? hi : v; }
