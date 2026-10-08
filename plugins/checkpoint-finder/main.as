// Checkpoint Finder: marks every checkpoint of the map you're on, so tiny hidden ones stop being a hunt.
// Spec: will-ness-ai/ballest-plugins#3.

[Setting name="Show and hide key" choices="F5|F6|F7|F8|F9|F10|F11|F12" description="Shows and hides the checkpoint markers"]
string ToggleKey = "F7";

Checkpoints cps;
Markers markers;
bool shown = true;
Input::Key toggle = Input::F7;

void Main()
{
    OnSettingsChanged();
}

void OnSettingsChanged()
{
    for (int code = Input::F1; code <= Input::F12; code++)
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
        return;
    }
    cps.Update();
    if (shown)
        markers.Show(cps);
    else
        markers.Hide();
}
