// The checkpoints of the map on screen, and which ones this run has touched.
//
// Checkpoints are the map's strips (Race::CheckpointPosition): the ones a run must clear before the finish opens,
// tiny hidden ones included. Not the goals (Ghosts::Checkpoint), which include the finish, can't tell it apart, and
// leave out the strips on maps with two or more goals.
//
// Touched: every checkpoint Race::CurrentCheckpoint has pointed at during this run. It moves to each checkpoint the
// ball touches and stays through respawns; a restart from the beginning is a new Race::RunId, and starts over.

class Checkpoints
{
    array<double> x, y, z;
    array<bool> touched;
    array<bool> placed;     // false for one whose position the host couldn't give (it's not drawn)
    // Bumped whenever the list is read again (a new map, or checkpoints that turned up late), so a view knows to
    // rebuild what it drew for the old list.
    int generation = 0;

    private string trackKey = "";
    private int run = -1;

    uint get_count() const property { return x.length(); }

    // Call every frame on a track.
    void Update()
    {
        string key = Race::TrackKey();
        if (key != trackKey)
        {
            trackKey = key;
            x.resize(0);        // a new map: nothing carries over
            Read();
        }
        else if (Race::CheckpointCount() != int(x.length()))
            Read();
        int now = Race::RunId();
        if (now != run)
        {
            run = now;
            ClearTouched();
        }
        int current = Race::CurrentCheckpoint();
        if (current >= 0 && current < int(touched.length()))
            touched[current] = true;
    }

    // Off a track: forget the map, so the next one is read fresh.
    void Leave()
    {
        trackKey = "";
        run = -1;
    }

    double DistanceSquared(uint k, double px, double py, double pz) const
    {
        double dx = x[k] - px, dy = y[k] - py, dz = z[k] - pz;
        return dx * dx + dy * dy + dz * dz;
    }

    // The untouched checkpoint nearest to a point, or -1 when every one is touched.
    int NearestUntouched(double px, double py, double pz) const
    {
        int nearest = -1;
        double best = 0;
        for (uint k = 0; k < x.length(); k++)
        {
            if (touched[k] || !placed[k])
                continue;
            double d = DistanceSquared(k, px, py, pz);
            if (nearest < 0 || d < best)
            {
                nearest = k;
                best = d;
            }
        }
        return nearest;
    }

    private void ClearTouched()
    {
        for (uint k = 0; k < touched.length(); k++)
            touched[k] = false;
    }

    private void Read()
    {
        // What was touched, by position: the host's list is sorted by position, so checkpoints that turn up a moment
        // after the map loads can move the others' indexes, and a mark has to follow its checkpoint, not its index.
        array<double> oldX = x, oldY = y, oldZ = z;
        array<bool> oldTouched = touched;
        x.resize(0);
        y.resize(0);
        z.resize(0);
        placed.resize(0);
        touched.resize(0);
        // Index for index with the host's list, so Race::CurrentCheckpoint names the same checkpoint here.
        for (int k = 0; k < Race::CheckpointCount(); k++)
        {
            double cx = 0, cy = 0, cz = 0;
            bool ok = Race::CheckpointPosition(k, cx, cy, cz);
            bool was = false;
            for (uint i = 0; ok && i < oldX.length(); i++)
                if (oldTouched[i] && oldX[i] == cx && oldY[i] == cy && oldZ[i] == cz)
                    was = true;
            x.insertLast(cx);
            y.insertLast(cy);
            z.insertLast(cz);
            placed.insertLast(ok);
            touched.insertLast(was);
        }
        generation++;
        Log::Info(x.length() + " checkpoints on " + trackKey);
    }
}
