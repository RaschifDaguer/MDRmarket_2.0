@extends('errors::minimal')

{{-- Se ve si la base de datos está apagada (ej. Aiven dormido) o con "php artisan down". --}}
@section('title', 'En mantenimiento')
@section('code', '503')
@section('message', 'En mantenimiento. Vuelve a intentar en unos minutos.')
