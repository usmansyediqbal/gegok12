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
        // Check if user is authenticated
        if (auth()->check()) {
            // Use user's preferred language from database
            $locale = auth()->user()->language ?? 'en';
        } elseif (Session::has('locale')) {
            // Use session locale for guests
            $locale = Session::get('locale');
        } else {
            // Default to English
            $locale = 'en';
        }

        // Set the application locale
        App::setLocale($locale);

        return $next($request);
    }
}
