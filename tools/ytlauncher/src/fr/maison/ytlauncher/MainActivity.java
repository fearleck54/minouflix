package fr.maison.ytlauncher;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.widget.Toast;

/** Tuile « YouTube » de l'écran d'accueil : lance TizenTube puis se ferme. */
public class MainActivity extends Activity {
    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        String p = "io.gh.reisxd.tizentube.cobalt";
        Intent i = getPackageManager().getLeanbackLaunchIntentForPackage(p);
        if (i == null) i = getPackageManager().getLaunchIntentForPackage(p);
        if (i != null) {
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            startActivity(i);
        } else {
            Toast.makeText(this, "TizenTube introuvable", Toast.LENGTH_LONG).show();
        }
        finish();
    }
}
