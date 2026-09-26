// Grind Stats: per-track grind stats, after Trackmania's Grinding Stats plugin.
//
//   TOTAL       1:42:17          time played on this track, all-time
//   SESSION     12:05            since this track was loaded
//   ATTEMPTS    318  +41         runs started, all-time and (lime) this session
//   FINISHES    27   +3          runs finished
//
// Everything comes from the game through the Race API: a run is counted once it goes active with a new
// Race::RunId (first start and every restart), a finish when Race::IsComplete turns on. Time counts while a race
// is active, the game isn't paused, and the player has steered or jumped within the last IDLE_AFTER seconds, the
// same idle rule Grinding Stats uses. The session starts again whenever the track is loaded (not on a restart).
//
// Stats are kept per Race::TrackKey in Storage, one "track:<key>" value each: "seconds attempts finishes".
// F6 hides and shows the card until the game closes, F8 writes the track's line to the log. The card can be
// dragged while the cursor is on screen.

[Setting name="Show card" description="Off hides the card; stats keep counting"]
bool ShowCard = true;

[Setting name="Background" min=0 max=1 description="How dark the box behind the card is (0: none)"]
float BackgroundOpacity = 0.72f;

const double IDLE_AFTER = 5.0;      // seconds without input before time stops counting
const double SAVE_EVERY = 10.0;     // seconds
const float LABEL_SIZE = 12, VALUE_SIZE = 15;
const float LIME_R = 0.80f, LIME_G = 1.0f, LIME_B = 0.0f;     // the game's menu highlight

class Counters
{
    double seconds = 0;
    int attempts = 0;
    int finishes = 0;
}

UI::Window@ card;
UI::Text@ totalText;
UI::Text@ sessionText;
UI::Text@ attemptsText;
UI::Text@ attemptsDelta;
UI::Text@ finishesText;
UI::Text@ finishesDelta;

string track = "";              // Race::TrackKey of the track being counted, "" off a track
Counters@ total = Counters();   // that track, all-time
Counters@ session = Counters(); // that track, since it loaded
int countedRun = -1;            // the Race::RunId last counted as an attempt
bool wasComplete = false;
double lastInput = 0;
double lastSave = 0;
bool dirty = false;
bool hiddenByKey = false;        // F6

void Main()
{
    //   TOTAL      1:42:17
    //   SESSION    12:05
    //   ATTEMPTS   318  +41
    //   FINISHES   27   +3
    @card = UI::CreateWindow();
    card.SetAnchor(0, 0);
    card.SetPivot(0, 0);
    card.SetOffset(40, 110);        // below the game's pause-screen PB box
    card.visible = false;
    Label("TOTAL");
    @totalText = Value();
    card.NewRow();
    Label("SESSION");
    @sessionText = Value();
    card.NewRow();
    Label("ATTEMPTS");
    @attemptsText = Value();
    @attemptsDelta = Delta();
    card.NewRow();
    Label("FINISHES");
    @finishesText = Value();
    @finishesDelta = Delta();
    card.movable = true;            // after SetOffset: that is where "reset position" puts it back
    OnSettingsChanged();
    lastInput = lastSave = Host::Time();
}

void Label(const string &in text)
{
    UI::Text@ t = card.AddText(text, LABEL_SIZE);
    t.SetColor(1, 1, 1, 0.65f);
    t.SetWidth(90);
}

UI::Text@ Value()
{
    UI::Text@ t = card.AddText("", VALUE_SIZE);
    t.SetWidth(70);
    return t;
}

UI::Text@ Delta()
{
    UI::Text@ t = card.AddText("", VALUE_SIZE);
    t.SetColor(LIME_R, LIME_G, LIME_B, 1);
    return t;
}

void OnSettingsChanged()
{
    card.SetBackground(0.08f, 0.08f, 0.09f, BackgroundOpacity);
}

// M:SS, or H:MM:SS from an hour
string TimeText(double seconds)
{
    int s = int(seconds);
    if (s >= 3600)
        return (s / 3600) + ":" + formatInt((s / 60) % 60, "0", 2) + ":" + formatInt(s % 60, "0", 2);
    return (s / 60) + ":" + formatInt(s % 60, "0", 2);
}

Counters@ Load(const string &in key)
{
    Counters@ c = Counters();
    array<string>@ parts = Storage::Get("track:" + key, "").split(" ");
    if (parts.length() == 3)
    {
        c.seconds = parseFloat(parts[0]);
        c.attempts = int(parseInt(parts[1]));
        c.finishes = int(parseInt(parts[2]));
    }
    return c;
}

void Save()
{
    if (track != "")
        Storage::Set("track:" + track, formatFloat(total.seconds, "", 0, 1) + " " + total.attempts + " " + total.finishes);
    lastSave = Host::Time();
    dirty = false;
}

void Report(const string &in why)
{
    if (track == "")
    {
        Log::Info(why + ": no track");
        return;
    }
    Log::Info(why + "  " + track + " | total " + TimeText(total.seconds) + "  session " + TimeText(session.seconds) +
              " | attempts " + total.attempts + " (+" + session.attempts + ") | finishes " + total.finishes +
              " (+" + session.finishes + ")");
}

// A new track, or the same one loaded again: a new session.
void Enter(const string &in key)
{
    if (track != "")
        Save();
    track = key;
    @total = Load(key);
    @session = Counters();
    countedRun = -1;
    wasComplete = Race::IsComplete();
    lastInput = Host::Time();
}

void Leave()
{
    if (track == "")
        return;
    Report("leave");
    Save();
    track = "";
}

void Update(float dt)
{
    double now = Host::Time();
    string key = Race::OnTrack() ? Race::TrackKey() : "";
    if (key != track)
    {
        Leave();
        if (key != "")
            Enter(key);
    }

    if (track != "")
    {
        // A run is counted once it is under way, so the pre-race screen's ball doesn't count twice.
        int run = Race::RunId();
        if (Race::IsActive() && run >= 0 && run != countedRun)
        {
            countedRun = run;
            total.attempts++;
            session.attempts++;
            dirty = true;
        }

        bool complete = Race::IsComplete();
        if (complete && !wasComplete)
        {
            total.finishes++;
            session.finishes++;
            Report("finish");
            Save();
        }
        wasComplete = complete;

        double x, y;
        bool jump;
        if (Race::GetInput(x, y, jump) && (x != 0 || y != 0 || jump))
            lastInput = now;
        if (Race::IsActive() && !Race::IsPaused() && now - lastInput <= IDLE_AFTER)
        {
            double step = dt > 1.0 ? 1.0 : dt;      // a hitch never adds more than a second
            total.seconds += step;
            session.seconds += step;
            dirty = true;
        }

        if (Input::Pressed(Input::F6))
            hiddenByKey = !hiddenByKey;
        if (Input::Pressed(Input::F8))
            Report("F8");
    }

    card.visible = track != "" && ShowCard && !hiddenByKey;
    if (card.visible)
    {
        totalText.text = TimeText(total.seconds);
        sessionText.text = TimeText(session.seconds);
        attemptsText.text = "" + total.attempts;
        attemptsDelta.text = "+" + session.attempts;
        finishesText.text = "" + total.finishes;
        finishesDelta.text = "+" + session.finishes;
    }

    if (dirty && now - lastSave > SAVE_EVERY)
        Save();
}
