// What the player sees for each checkpoint: a small glowing ball on it in the world, and a dot over it on the screen
// that walls never hide, bigger the closer it is. The nearest untouched one says how far it is. Touched ones are grey
// and faint. Settled in-game on the prototype branch claude/prototype-checkpoint-finder (rounds E, E3 and T1).

const double kBallRadius = 60;
const float kBallGlow = 8;
const float kTouchedGlow = 1;
const float kDotLargest = 44;          // px, at the checkpoint
const float kDotSmallest = 12;         // px, from 128 m away
const double kShrinkPerPixel = 400;    // cm farther for each pixel smaller
const float kEdge = 24;                // dots off the screen stay this far inside its edge
const float kTouchedGrey = 0.45f;
const float kTouchedOpacity = 0.4f;

// One colour per checkpoint, cycling, so neighbours tell apart.
const array<float> kPalette = {
    1.0f, 0.35f, 0.25f,   0.25f, 0.8f, 1.0f,   1.0f, 0.85f, 0.2f,   0.5f, 1.0f, 0.35f,
    0.85f, 0.4f, 1.0f,    1.0f, 0.55f, 0.15f,  0.2f, 1.0f, 0.8f,    1.0f, 0.45f, 0.75f
};

class Dot
{
    UI::Window@ circle;     // a window whose corner radius is half its size
    UI::Window@ label;
    UI::Text@ labelText;

    Dot()
    {
        @circle = Bare();
        @label = Bare();
        label.SetBackground(0, 0, 0, 0.55f);
        label.SetCornerRadius(6);
        label.SetPadding(6, 1);
        @labelText = label.AddText("", 13);
    }

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
        if (builtFor != cps.generation || (balls.length() > 0 && !Draw::Show(balls[0], true)))
            MakeBalls(cps);
        for (uint k = 0; k < balls.length(); k++)
            if (cps.touched[k] != ballTouched[k])
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

    private void MakeBalls(const Checkpoints@ cps)
    {
        Hide();
        builtFor = cps.generation;
        for (uint k = 0; k < cps.count; k++)
        {
            float r, g, b;
            Colour(k, cps.touched[k], r, g, b);
            int ball = Draw::Ball(kBallRadius, r, g, b, true);
            Draw::Move(ball, cps.x[k], cps.y[k], cps.z[k]);
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
            if (k >= cps.count || !Camera::Project(cps.x[k], cps.y[k], cps.z[k], sx, sy))
            {
                dot.Hide();     // behind the camera
                continue;
            }
            sx = Clamp(sx, kEdge, w - kEdge);
            sy = Clamp(sy, kEdge, h - kEdge);
            double d = ball ? Math::sqrt(cps.DistanceSquared(k, bx, by, bz)) : 0;
            float size = Clamp(kDotLargest - float(d / kShrinkPerPixel), kDotSmallest, kDotLargest);
            float r, g, b;
            Colour(k, cps.touched[k], r, g, b);
            dot.circle.SetBackground(r, g, b, cps.touched[k] ? kTouchedOpacity : 1);
            dot.circle.SetCornerRadius(size / 2);
            dot.circle.SetRect(sx - size / 2, sy - size / 2, size, size);
            dot.circle.visible = true;
            bool labelled = int(k) == nearest;
            if (labelled)
            {
                dot.labelText.text = int(d / 100) + " m";
                dot.labelText.SetColor(r, g, b, 1);
                // Under the dot, or over it when the dot is pinned to the bottom edge.
                float labelY = sy + size / 2 + 4;
                if (labelY + 20 > h)
                    labelY = sy - size / 2 - 24;
                dot.label.SetRect(sx - 30, labelY, 60, 20);
            }
            dot.label.visible = labelled;
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
