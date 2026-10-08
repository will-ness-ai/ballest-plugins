// ==== PROTOTYPE (grill-design round 2: E won round 1; how do the checkpoints show through walls?) ====
// Every variant keeps round 1's E: a small glowing ball on each checkpoint and a glowing line from the ball to the
// nearest one. On top, each draws a marker on the screen over every checkpoint, so walls never hide it. Markers off
// the screen's sides are pinned to its edge; ones behind the camera aren't shown. Not the plugin: the winner is rebuilt
// properly afterwards.
//   F7               show / hide the checkpoints
//   PageUp/PageDown  previous / next variant (the pill at the top names the current one)
// Checkpoints are the track's strips (Race::CheckpointPosition), the ones a run must clear before the finish opens;
// the goals (Ghosts::Checkpoint) include the finish and miss the tiny hidden strips.

const array<string> kVariants = {
    "E1 · Dots: a small solid dot on each checkpoint",
    "E2 · Numbered dots: a bigger dot with the checkpoint's number in it",
    "E3 · Growing dots: bigger as you get closer; the nearest says how far",
    "E4 · Rings: a ring on each, with its distance under it",
    "E5 · Nearest first: a big dot and distance on the nearest, faint dots on the rest"
};

// One colour per checkpoint number, cycling.
const array<float> kPalette = {
    1.0f, 0.35f, 0.25f,   0.25f, 0.8f, 1.0f,   1.0f, 0.85f, 0.2f,   0.5f, 1.0f, 0.35f,
    0.85f, 0.4f, 1.0f,    1.0f, 0.55f, 0.15f,  0.2f, 1.0f, 0.8f,    1.0f, 0.45f, 0.75f
};

int variant = 0;
bool shown = true;

string trackKey = "";
bool built = false;

array<double> cx, cy, cz;
array<int> numbers;
array<int> balls;           // a small glowing ball on each checkpoint
int guide = 0;              // the line to the nearest checkpoint
float guideAge = 0;

UI::Window@ pill;
UI::Text@ pillText;

// One marker per checkpoint: a round window (its corner radius half its size), an inner one for a ring's hole, and
// a label window under it for the distance.
class Marker
{
    UI::Window@ dot;
    UI::Text@ number;
    UI::Window@ hole;
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
    @m.number = m.dot.AddTextAt("", 14, 0, 0);
    m.number.SetAlign(1);
    m.number.SetColor(0, 0, 0, 1);
    @m.hole = Bare(61);
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
    m.hole.visible = false;
    m.label.visible = false;
}

void ReadCheckpoints()
{
    cx.resize(0);
    cy.resize(0);
    cz.resize(0);
    numbers.resize(0);
    for (int k = 0; k < Race::CheckpointCount(); k++)
    {
        double x, y, z;
        if (!Race::CheckpointPosition(k, x, y, z))
            continue;
        numbers.insertLast(k + 1);
        cx.insertLast(x);
        cy.insertLast(y);
        cz.insertLast(z);
    }
    Log::Info("checkpoint-finder: " + numbers.length() + " checkpoints on " + trackKey);
}

void Colour(int k, float &out r, float &out g, float &out b)
{
    int c = (numbers[k] > 0 ? numbers[k] - 1 : k) % (kPalette.length() / 3);
    r = kPalette[c * 3];
    g = kPalette[c * 3 + 1];
    b = kPalette[c * 3 + 2];
}

void TearDown()
{
    for (uint i = 0; i < balls.length(); i++)
        Draw::Remove(balls[i]);
    balls.resize(0);
    if (guide != 0)
        Draw::Remove(guide);
    guide = 0;
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
    for (uint k = 0; k < numbers.length(); k++)
    {
        float r, g, b;
        Colour(k, r, g, b);
        int ball = Draw::Ball(60, r, g, b, true);
        Draw::Move(ball, cx[k], cy[k], cz[k]);
        balls.insertLast(ball);
    }
}

void UpdateGuide(float dt, int nearest, double bx, double by, double bz)
{
    guideAge += dt;
    if (guideAge < 0.15f)
        return;
    guideAge = 0;
    if (guide != 0)
        Draw::Remove(guide);
    guide = 0;
    if (nearest < 0)
        return;
    float r, g, b;
    Colour(nearest, r, g, b);
    array<double> line = {bx, by, bz + 60, cx[nearest], cy[nearest], cz[nearest]};
    guide = Draw::Tube(line, 8, r, g, b, true);
}

string Metres(double d) { return int(d / 100) + " m"; }

void UpdateMarkers(int nearest, bool ball, double bx, double by, double bz)
{
    float w, h;
    if (!UI::ScreenSize(w, h))
        return;
    while (markers.length() < numbers.length())
        markers.insertLast(MakeMarker());
    for (uint k = 0; k < markers.length(); k++)
    {
        Marker@ m = markers[k];
        float sx, sy;
        if (k >= numbers.length() || !Camera::Project(cx[k], cy[k], cz[k], sx, sy))
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
        float r, g, b;
        Colour(k, r, g, b);
        float size = 16, alpha = 1;
        bool showNumber = false, ring = false, showDistance = false;
        if (variant == 1)
        {
            size = 26;
            showNumber = true;
        }
        else if (variant == 2)
        {
            size = float(Max(12, Min(44, 44 - d / 400)));
            showDistance = int(k) == nearest;
        }
        else if (variant == 3)
        {
            size = 26;
            ring = true;
            showDistance = ball;
        }
        else if (variant == 4)
        {
            bool near = int(k) == nearest;
            size = near ? 34 : 12;
            alpha = near ? 1 : 0.45f;
            showDistance = near;
        }
        m.dot.SetBackground(r, g, b, alpha);
        m.dot.SetCornerRadius(size / 2);
        m.dot.SetRect(sx - size / 2, sy - size / 2, size, size);
        m.number.text = showNumber ? "" + (numbers[k] > 0 ? numbers[k] : int(k + 1)) : "";
        m.number.SetWidth(size);
        m.number.SetPosition(0, size / 2 - 9);
        m.dot.visible = true;
        if (ring)
        {
            float inner = size - 8;
            m.hole.SetBackground(0.05f, 0.05f, 0.08f, 0.6f);
            m.hole.SetCornerRadius(inner / 2);
            m.hole.SetRect(sx - inner / 2, sy - inner / 2, inner, inner);
        }
        m.hole.visible = ring;
        if (showDistance && ball)
        {
            m.labelText.text = Metres(d);
            m.labelText.SetColor(r, g, b, 1);
            m.label.SetRect(sx - 30, sy + size / 2 + 4, 60, 20);
        }
        m.label.visible = showDistance && ball;
    }
}

void Update(float dt)
{
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
        trackKey = "";
        return;
    }

    // A new map, or its checkpoints turned up late: read them again. Shapes go with the old map by themselves.
    string key = Race::TrackKey();
    if (key != trackKey || Race::CheckpointCount() != int(numbers.length()))
    {
        trackKey = key;
        balls.resize(0);
        guide = 0;
        ReadCheckpoints();
        built = false;
    }
    if (!built)
        Build();

    pillText.text = "PROTOTYPE  " + kVariants[variant] + "   |   " + numbers.length() + " checkpoints   |   F7 " +
                    (shown ? "hide" : "show") + "   PgUp/PgDn variant";

    if (!shown)
        return;
    double bx, by, bz;
    bool ball = Race::BallPosition(bx, by, bz);
    int nearest = -1;
    double bestD = 1e30;
    if (ball)
        for (uint k = 0; k < numbers.length(); k++)
        {
            double dx = cx[k] - bx, dy = cy[k] - by, dz = cz[k] - bz;
            double d = dx * dx + dy * dy + dz * dz;
            if (d < bestD)
            {
                bestD = d;
                nearest = k;
            }
        }
    UpdateGuide(dt, nearest, bx, by, bz);
    UpdateMarkers(nearest, ball, bx, by, bz);
}
// ==== END PROTOTYPE ====
