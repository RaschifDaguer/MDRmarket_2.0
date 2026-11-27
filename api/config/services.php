<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Mailgun, Postmark, AWS and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'token' => env('POSTMARK_TOKEN'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'resend' => [
        'key' => env('RESEND_KEY'),
    ],

    // Mapas (ver App\Support\Mapas): servicios gratis y sin clave de
    // OpenStreetMap. Sus políticas de uso piden identificar la app.
    'mapas' => [
        'rutas_url' => env('MAPAS_RUTAS_URL', 'https://routing.openstreetmap.de'),
        'direcciones_url' => env('MAPAS_DIRECCIONES_URL', 'https://nominatim.openstreetmap.org'),
        'agente' => env('MAPAS_AGENTE', 'MDRMarket/1.2 (+'.env('APP_URL', 'https://mdrmarket.sistemasunifranz.site').')'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

];
