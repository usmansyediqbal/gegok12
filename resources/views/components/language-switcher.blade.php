<div class="flex items-center space-x-2">
    <form action="{{ route('language.switch') }}" method="POST" class="inline">
        @csrf
        <select name="locale" onchange="this.form.submit()" class="text-sm border rounded px-2 py-1">
            <option value="en" {{ app()->getLocale() == 'en' ? 'selected' : '' }}>English</option>
            <option value="fr" {{ app()->getLocale() == 'fr' ? 'selected' : '' }}>Français</option>
        </select>
    </form>
</div>