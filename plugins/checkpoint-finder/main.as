// ==== PROTOTYPE (grill-design round 1: how should the checkpoints be shown?) ====
// Five variants of one question, to compare in-game. Not the plugin: the winner is rebuilt properly afterwards.
//   F7               show / hide the checkpoints
//   PageUp/PageDown  previous / next variant (the pill at the top names the current one)
// Checkpoints are the track's goals (Ghosts::Checkpoint), the ones a run must touch before the finish.

const array<string> kVariants = {
    "A · Pillars: a tall glowing beam from each checkpoint",
    "B · Screen tags: number and distance over each one, through walls",
    "C · Beacons: a big pulsing glowing ball on each one",
    "D · Overview: a top-down camera over the whole map (F7 toggles it)",
    "E · Guide line: a glowing line from the ball to the nearest checkpoint"
};

// One colour per checkpoint number, cycling.
const array<float> kPalette = {
    1.0f, 0.35f, 0.25f,   0.25f, 0.8f, 1.0f,   1.0f, 0.85f, 0.2f,   0.5f, 1.0f, 0.35f,
    0.85f, 0.4f, 1.0f,    1.0f, 0.55f, 0.15f,  0.2f, 1.0f, 0.8f,    1.0f, 0.45f, 0.75f
};

int variant = 0;
bool shown = true;

string trackKey = "";
int builtVariant = -1;
bool built = false;

array<double> cx, cy, cz;
array<int> numbers;
array<int> shapes;          // Draw ids of the current variant
int guide = 0;              // E: the line to the nearest checkpoint
float guideAge = 0;
float time = 0;

UI::Window@ pill;
UI::Text@ pillText;
UI::Window@ overlay;
array<UI::Text@> tags;

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

    @overlay = UI::CreateWindow();
    overlay.SetBackground(0, 0, 0, 0);
    overlay.SetPadding(0, 0);
    overlay.SetBlocksClicks(false);
    overlay.zOrder = 50;
}

double Min(double a, double b) { return a < b ? a : b; }
double Max(double a, double b) { return a > b ? a : b; }

void ReadCheckpoints()
{
    cx.resize(0);
    cy.resize(0);
    cz.resize(0);
    numbers.resize(0);
    for (int k = 0; k < Ghosts::CheckpointCount(); k++)
    {
        int n;
        double x, y, z;
        if (!Ghosts::Checkpoint(k, n, x, y, z))
            continue;
        numbers.insertLast(n);
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
    for (uint i = 0; i < shapes.length(); i++)
        Draw::Remove(shapes[i]);
    shapes.resize(0);
    if (guide != 0)
        Draw::Remove(guide);
    guide = 0;
    for (uint i = 0; i < tags.length(); i++)
        tags[i].text = "";
    if (Camera::IsTaken())
        Camera::Release();
    built = false;
}

void Build()
{
    TearDown();
    builtVariant = variant;
    built = true;
    if (!shown)
        return;
    for (uint k = 0; k < numbers.length(); k++)
    {
        float r, g, b;
        Colour(k, r, g, b);
        if (variant == 0)
        {
            array<double> beam = {cx[k], cy[k], cz[k] - 200, cx[k], cy[k], cz[k] + 6000};
            shapes.insertLast(Draw::Tube(beam, 40, r, g, b, true));
        }
        else if (variant == 2)
        {
            int ball = Draw::Ball(220, r, g, b, true);
            Draw::Move(ball, cx[k], cy[k], cz[k]);
            shapes.insertLast(ball);
        }
        else if (variant == 3)
        {
            int ball = Draw::Ball(400, r, g, b, true);
            Draw::Move(ball, cx[k], cy[k], cz[k]);
            shapes.insertLast(ball);
        }
        else if (variant == 4)
        {
            int ball = Draw::Ball(60, r, g, b, true);
            Draw::Move(ball, cx[k], cy[k], cz[k]);
            shapes.insertLast(ball);
        }
    }
    if (variant == 3)
        StartOverview();
}

// D: a camera straight down over every checkpoint and the ball.
void StartOverview()
{
    if (numbers.length() == 0)
        return;
    double minX = cx[0], maxX = cx[0], minY = cy[0], maxY = cy[0], maxZ = cz[0];
    for (uint k = 1; k < numbers.length(); k++)
    {
        minX = Min(minX, cx[k]);
        maxX = Max(maxX, cx[k]);
        minY = Min(minY, cy[k]);
        maxY = Max(maxY, cy[k]);
        maxZ = Max(maxZ, cz[k]);
    }
    double bx, by, bz;
    if (Race::BallPosition(bx, by, bz))
    {
        minX = Min(minX, bx);
        maxX = Max(maxX, bx);
        minY = Min(minY, by);
        maxY = Max(maxY, by);
        maxZ = Max(maxZ, bz);
    }
    double extent = Max(maxX - minX, maxY - minY) * 0.5 + 1500;
    if (!Camera::Take())
        return;
    // fov 90: half the view is as wide as the camera is high.
    Camera::Set((minX + maxX) * 0.5, (minY + maxY) * 0.5, maxZ + extent * 1.1, -89.9, 0, 90);
}

void UpdateTags()
{
    float w, h;
    if (!UI::ScreenSize(w, h))
        return;
    overlay.SetRect(0, 0, w, h);
    while (tags.length() < numbers.length())
    {
        UI::Text@ t = overlay.AddTextAt("", 18, 0, 0);
        t.SetWidth(140);
        t.SetAlign(1);
        tags.insertLast(t);
    }
    double bx, by, bz;
    bool ball = Race::BallPosition(bx, by, bz);
    for (uint k = 0; k < tags.length(); k++)
    {
        if (k >= numbers.length())
        {
            tags[k].text = "";
            continue;
        }
        float sx, sy;
        if (!Camera::Project(cx[k], cy[k], cz[k], sx, sy))
        {
            tags[k].text = "";
            continue;
        }
        // Off the screen's sides: pinned to the edge, pointing the way.
        string arrow = "";
        if (sx < 40) { sx = 40; arrow = "< "; }
        if (sx > w - 40) { sx = w - 40; arrow = "> "; }
        if (sy < 40) { sy = 40; arrow = "^ "; }
        if (sy > h - 40) { sy = h - 40; arrow = "v "; }
        string label = arrow + "◆ " + (numbers[k] > 0 ? numbers[k] : int(k + 1));
        if (ball)
        {
            double dx = cx[k] - bx, dy = cy[k] - by, dz = cz[k] - bz;
            label += "  " + int(Math::sqrt(dx * dx + dy * dy + dz * dz) / 100) + " m";
        }
        float r, g, b;
        Colour(k, r, g, b);
        tags[k].text = label;
        tags[k].SetColor(r, g, b, 1);
        tags[k].SetPosition(sx - 70, sy - 11);
    }
}

void UpdateGuide(float dt)
{
    guideAge += dt;
    if (guideAge < 0.15f)
        return;
    guideAge = 0;
    double bx, by, bz;
    if (!Race::BallPosition(bx, by, bz) || numbers.length() == 0)
        return;
    int best = 0;
    double bestD = 1e30;
    for (uint k = 0; k < numbers.length(); k++)
    {
        double dx = cx[k] - bx, dy = cy[k] - by, dz = cz[k] - bz;
        double d = dx * dx + dy * dy + dz * dz;
        if (d < bestD) { bestD = d; best = k; }
    }
    if (guide != 0)
        Draw::Remove(guide);
    float r, g, b;
    Colour(best, r, g, b);
    array<double> line = {bx, by, bz + 60, cx[best], cy[best], cz[best]};
    guide = Draw::Tube(line, 8, r, g, b, true);
}

void Update(float dt)
{
    time += dt;
    if (Input::Pressed(Input::PageDown)) { variant = (variant + 1) % kVariants.length(); built = false; }
    if (Input::Pressed(Input::PageUp)) { variant = (variant + kVariants.length() - 1) % kVariants.length(); built = false; }
    if (Input::Pressed(Input::F7)) { shown = !shown; built = false; }

    bool onTrack = Race::OnTrack();
    pill.visible = onTrack;
    overlay.visible = onTrack && shown && variant == 1;
    if (!onTrack)
    {
        if (Camera::IsTaken())
            Camera::Release();
        trackKey = "";
        return;
    }

    // A new map, or its checkpoints turned up late: read them again. Shapes go with the old map by themselves.
    string key = Race::TrackKey();
    if (key != trackKey || Ghosts::CheckpointCount() != int(numbers.length()))
    {
        trackKey = key;
        shapes.resize(0);
        guide = 0;
        ReadCheckpoints();
        built = false;
    }
    if (!built || builtVariant != variant)
        Build();

    pillText.text = "PROTOTYPE  " + kVariants[variant] + "   |   " + numbers.length() + " checkpoints   |   F7 " +
                    (shown ? "hide" : "show") + "   PgUp/PgDn variant";

    if (!shown)
        return;
    if (variant == 1)
        UpdateTags();
    else if (variant == 2)
    {
        // Pulse so they catch the eye from afar.
        float pulse = 0.6f + 0.4f * float(Math::sin(time * 4));
        for (uint k = 0; k < shapes.length(); k++)
        {
            float r, g, b;
            Colour(k, r, g, b);
            Draw::Glow(shapes[k], r, g, b, pulse * 8);
        }
    }
    else if (variant == 4)
        UpdateGuide(dt);
}
// ==== END PROTOTYPE ====
