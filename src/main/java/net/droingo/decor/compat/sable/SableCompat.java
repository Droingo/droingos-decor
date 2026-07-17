package net.droingo.decor.compat.sable;

import net.droingo.decor.DroingosDecor;

/**
 * Entry point for all Sable-specific code.
 *
 * Keep Sable API calls isolated in this package so ordinary decor remains
 * lightweight and the motion-reactive system can be developed independently.
 */
public final class SableCompat {
    private SableCompat() {
    }

    public static void init() {
        DroingosDecor.LOGGER.info("Sable integration enabled for Droingo's Decor.");
    }
}
