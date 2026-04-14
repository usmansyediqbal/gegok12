<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\App;
use Illuminate\Support\Facades\Session;

class SetLocale
{
    public function handle(Request $request, Closure $next)
    {
        try {
            // Check if user is authenticated
            if (auth()->check() && auth()->user()) {
                // Use user's preferred language from database
                $locale = auth()->user()->language ?? 'en';
            } elseif (Session::has('locale')) {
                // Use session locale for guests
                $locale = Session::get('locale');
            } else {
                // Default to English
                $locale = 'en';
            }

            // Validate locale
            $availableLocales = config('app.available_locales', ['en', 'fr']);
            if (! in_array($locale, $availableLocales)) {
                $locale = 'en';
            }

            // Set the application locale
            App::setLocale($locale);
        } catch (\Exception $e) {
            // Fallback to English if any error
            App::setLocale('en');
        }

        return $next($request);
    }
}
