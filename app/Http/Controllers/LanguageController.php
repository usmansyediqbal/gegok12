<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\App;
use Illuminate\Support\Facades\Session;

class LanguageController extends Controller
{
    public function switch(Request $request)
    {
        $locale = $request->input('locale');
        
        // Validate locale
        $availableLocales = config('app.available_locales', ['en', 'fr']);
        
        if (!in_array($locale, $availableLocales)) {
            return redirect()->back()->with('error', 'Langue non supportée.');
        }
        
        // Store locale in session for guests
        Session::put('locale', $locale);
        
        // Update user's language preference if authenticated
        if (auth()->check()) {
            $user = auth()->user();
            $user->language = $locale;
            $user->save();
        }
        
        // Set application locale
        App::setLocale($locale);
        
        return redirect()->back()->with('success', 'Langue changée avec succès.');
    }
}