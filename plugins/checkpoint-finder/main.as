// Checkpoint Finder: marks every checkpoint of the map you're on, so tiny hidden ones stop being a hunt.
// Spec: will-ness-ai/ballest-plugins#3.

[Setting name="Show and hide key" choices="F5|F6|F7|F8|F9|F10|F11|F12" description="Shows and hides the checkpoint markers"]
string ToggleKey = "F7";

Checkpoints cps;
Markers markers;
bool shown = true;
Input::Key toggle = Input::F7;
string trackKey = "";

void Main()
{
    OnSettingsChanged();
}

void OnSettingsChanged()
{
    // The function keys are 0x70 (F1) onwards.
    for (int code = 0x70; code <= 0x7B; code++)
        if (Input::Name(Input::Key(code)) == ToggleKey)
            toggle = Input::Key(code);
}

void Update(float dt)
{
    if (Input::Pressed(toggle))
        shown = !shown;

    if (!Race::OnTrack())
    {
        markers.Hide();
        cps.Leave();
        trackKey = "";
        return;
    }
    string key = Race::TrackKey();
    if (key != trackKey)
    {
        trackKey = key;
        markers.Forget();       // the old map's shapes went with it
    }
    cps.Update();
    if (shown)
        markers.Show(cps);
    else
        markers.Hide();
}
