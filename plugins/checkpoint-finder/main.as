// ==== PROTOTYPE (grill-design round 3: how do checkpoints you've already touched look?) ====
// Settled so far: round 1 E (a small glowing ball on each checkpoint), round 2 E3 (a dot on the screen over each
// one, through walls, bigger as you get closer, the nearest saying how far), and no line to the nearest (Will,
// round 2). Each variant here changes only the checkpoints touched this run. Not the plugin: the winner is rebuilt
// properly afterwards.
//   F7               show / hide the checkpoints
//   PageUp/PageDown  previous / next variant (the pill at the top names the current one)
// Checkpoints are the track's strips (Race::CheckpointPosition), the ones a run must clear before the finish opens.
// Touched: every checkpoint Race::CurrentCheckpoint has pointed at this run (it moves to each one you touch);
// a restart from the beginning (a new RunId) clears them.

const array<string> kVariants = {
    "T1 · Dimmed: touched ones turn grey and faint",
    "T2 · Hidden: touched ones disappear, ball and dot",
    "T3 · Ticked: touched ones turn into a small green dot",
    "T4 · Kept: touched ones stay as they are, untouched ones pulse",
    "T5 · Hidden + count: touched ones disappear, a count of what's left sits under the pill"
};

// One colour per checkpoint, cycling.
const array<float> kPalette = {
    1.0f, 0.35f, 0.25f,   0.25f, 0.8f, 1.0f,   1.0f, 0.85f, 0.2f,   0.5f, 1.0f, 0.35f,
    0.85f, 0.4f, 1.0f,    1.0f, 0.55f, 0.15f,  0.2f, 1.0f, 0.8f,    1.0f, 0.45f, 0.75f
};

int variant = 0;
bool shown = true;

string trackKey = "";
bool built = false;

array<double> cx, cy, cz;
array<bool> touched;
array<int> balls;           // a small glowing ball on each checkpoint
array<int> ballLook;        // what each ball is drawn as now: 0 its colour, 1 grey, 2 green, 3 hidden
int run = -1;
float time = 0;

UI::Window@ pill;
UI::Text@ pillText;
UI::Window@ counter;
UI::Text@ counterText;

// One marker per checkpoint: a round window (its corner radius half its size) and a label under it for the distance.
class Marker
{
    UI::Window@ dot;
    UI::Window@ label;
    UI::Text@ labelText;
}
array<Marker@> markers;

void Main()
{
    @pill = UI::CreateWindow();
    pill.SetAnchor(0.5f, 0);
    pill.SetPivot(0.5f, 0);
    pill.SetOffset(0, 12);
    pill.SetBackground(1, 0.1f, 0.6f, 0.9f);
    pill.SetCornerRadius(16);
    pill.SetPadding(14, 6);
    pill.zOrder = 900;
    @pillText = pill.AddText("", 15);
    pillText.SetColor(1, 1, 1, 1);

    @counter = UI::CreateWindow();
    counter.SetAnchor(0.5f, 0);
    counter.SetPivot(0.5f, 0);
    counter.SetOffset(0, 52);
    counter.SetBackground(0, 0, 0, 0.55f);
    counter.SetCornerRadius(10);
    counter.SetPadding(12, 4);
    @counterText = counter.AddText("", 18);
    counter.visible = false;
}

double Min(double a, double b) { return a < b ? a : b; }
double Max(double a, double b) { return a > b ? a : b; }

UI::Window@ Bare(int z)
{
    UI::Window@ w = UI::CreateWindow();
    w.SetPadding(0, 0);
    w.SetBlocksClicks(false);
    w.zOrder = z;
    w.visible = false;
    return w;
}

Marker@ MakeMarker()
{
    Marker m;
    @m.dot = Bare(60);
    @m.label = Bare(60);
    m.label.SetBackground(0, 0, 0, 0.55f);
    m.label.SetCornerRadius(6);
    m.label.SetPadding(6, 1);
    @m.labelText = m.label.AddText("", 13);
    return m;
}

void HideMarker(Marker@ m)
{
    m.dot.visible = false;
    m.label.visible = false;
}

void ReadCheckpoints()
{
    cx.resize(0);
    cy.resize(0);
    cz.resize(0);
    for (int k = 0; k < Race::CheckpointCount(); k++)
    {
        double x, y, z;
        if (!Race::CheckpointPosition(k, x, y, z))
            continue;
        cx.insertLast(x);
        cy.insertLast(y);
        cz.insertLast(z);
    }
    touched.resize(cx.length());
    for (uint k = 0; k < touched.length(); k++)
        touched[k] = false;
    Log::Info("checkpoint-finder: " + cx.length() + " checkpoints on " + trackKey);
}

void Colour(int k, float &out r, float &out g, float &out b)
{
    int c = k % (kPalette.length() / 3);
    r = kPalette[c * 3];
    g = kPalette[c * 3 + 1];
    b = kPalette[c * 3 + 2];
}

// How a checkpoint is drawn in this variant: 0 its colour, 1 grey, 2 green, 3 hidden.
int Look(int k)
{
    if (!touched[k])
        return 0;
    if (variant == 0)
        return 1;
    if (variant == 2)
        return 2;
    if (variant == 3)
        return 0;
    return 3;
}

void LookColour(int k, int look, float &out r, float &out g, float &out b)
{
    if (look == 1) { r = 0.45f; g = 0.45f; b = 0.45f; }
    else if (look == 2) { r = 0.3f; g = 1; b = 0.3f; }
    else Colour(k, r, g, b);
}

void TearDown()
{
    for (uint i = 0; i < balls.length(); i++)
        Draw::Remove(balls[i]);
    balls.resize(0);
    ballLook.resize(0);
    for (uint i = 0; i < markers.length(); i++)
        HideMarker(markers[i]);
    built = false;
}

void Build()
{
    TearDown();
    built = true;
    if (!shown)
        return;
    for (uint k = 0; k < cx.length(); k++)
    {
        float r, g, b;
        Colour(k, r, g, b);
        int ball = Draw::Ball(60, r, g, b, true);
        Draw::Move(ball, cx[k], cy[k], cz[k]);
        balls.insertLast(ball);
        ballLook.insertLast(0);
    }
}

void UpdateBalls()
{
    float pulse = 0.55f + 0.45f * float(Math::sin(time * 5));
    for (uint k = 0; k < balls.length(); k++)
    {
        int look = Look(k);
        if (look != ballLook[k])
        {
            Draw::Show(balls[k], look != 3);
            ballLook[k] = look;
        }
        float r, g, b;
        LookColour(k, look, r, g, b);
        float bright = look == 1 ? 1 : 8;
        if (variant == 3 && !touched[k])
            bright = 8 * pulse;
        Draw::Glow(balls[k], r, g, b, bright);
    }
}

string Metres(double d) { return int(d / 100) + " m"; }

void UpdateMarkers(bool ball, double bx, double by, double bz)
{
    float w, h;
    if (!UI::ScreenSize(w, h))
        return;
    while (markers.length() < cx.length())
        markers.insertLast(MakeMarker());

    // The nearest untouched one gets the distance.
    int nearest = -1;
    double bestD = 1e30;
    if (ball)
        for (uint k = 0; k < cx.length(); k++)
        {
            if (touched[k] && variant != 3)
                continue;
            double dx = cx[k] - bx, dy = cy[k] - by, dz = cz[k] - bz;
            double d = dx * dx + dy * dy + dz * dz;
            if (d < bestD)
            {
                bestD = d;
                nearest = k;
            }
        }

    float pulse = 0.55f + 0.45f * float(Math::sin(time * 5));
    for (uint k = 0; k < markers.length(); k++)
    {
        Marker@ m = markers[k];
        float sx, sy;
        if (k >= cx.length() || Look(k) == 3 || !Camera::Project(cx[k], cy[k], cz[k], sx, sy))
        {
            HideMarker(m);
            continue;
        }
        sx = float(Max(24, Min(w - 24, sx)));
        sy = float(Max(24, Min(h - 24, sy)));
        double d = 0;
        if (ball)
        {
            double dx = cx[k] - bx, dy = cy[k] - by, dz = cz[k] - bz;
            d = Math::sqrt(dx * dx + dy * dy + dz * dz);
        }
        int look = Look(k);
        float r, g, b;
        LookColour(k, look, r, g, b);
        float size = float(Max(12, Min(44, 44 - d / 400)));
        float alpha = 1;
        if (look == 1)
            alpha = 0.4f;
        if (look == 2)
            size = 12;
        if (variant == 3 && !touched[k])
            alpha = 0.5f + 0.5f * pulse;
        m.dot.SetBackground(r, g, b, alpha);
        m.dot.SetCornerRadius(size / 2);
        m.dot.SetRect(sx - size / 2, sy - size / 2, size, size);
        m.dot.visible = true;
        bool showDistance = ball && int(k) == nearest;
        if (showDistance)
        {
            m.labelText.text = Metres(d);
            m.labelText.SetColor(r, g, b, 1);
            m.label.SetRect(sx - 30, sy + size / 2 + 4, 60, 20);
        }
        m.label.visible = showDistance;
    }
}

void Update(float dt)
{
    time += dt;
    if (Input::Pressed(Input::PageDown))
        variant = (variant + 1) % kVariants.length();
    if (Input::Pressed(Input::PageUp))
        variant = (variant + kVariants.length() - 1) % kVariants.length();
    if (Input::Pressed(Input::F7))
    {
        shown = !shown;
        built = false;
    }

    bool onTrack = Race::OnTrack();
    pill.visible = onTrack;
    if (!onTrack)
    {
        for (uint i = 0; i < markers.length(); i++)
            HideMarker(markers[i]);
        counter.visible = false;
        trackKey = "";
        return;
    }

    // A new map, or its checkpoints turned up late: read them again. Shapes go with the old map by themselves.
    string key = Race::TrackKey();
    if (key != trackKey || Race::CheckpointCount() != int(cx.length()))
    {
        trackKey = key;
        balls.resize(0);
        ballLook.resize(0);
        ReadCheckpoints();
        built = false;
    }
    if (!built)
        Build();

    // A restart from the beginning is a new run: nothing touched yet.
    int now = Race::RunId();
    if (now != run)
    {
        run = now;
        for (uint k = 0; k < touched.length(); k++)
            touched[k] = false;
    }
    int current = Race::CurrentCheckpoint();
    if (current >= 0 && current < int(touched.length()))
        touched[current] = true;

    int left = 0;
    for (uint k = 0; k < touched.length(); k++)
        if (!touched[k])
            left++;

    pillText.text = "PROTOTYPE  " + kVariants[variant] + "   |   " + cx.length() + " checkpoints   |   F7 " +
                    (shown ? "hide" : "show") + "   PgUp/PgDn variant";
    counter.visible = shown && variant == 4;
    counterText.text = left == 0 ? "All checkpoints touched" : left + " of " + cx.length() + " left";

    if (!shown)
        return;
    double bx, by, bz;
    bool ball = Race::BallPosition(bx, by, bz);
    UpdateBalls();
    UpdateMarkers(ball, bx, by, bz);
}
// ==== END PROTOTYPE ====
