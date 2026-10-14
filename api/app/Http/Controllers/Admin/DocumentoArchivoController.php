<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Documento;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\HttpFoundation\StreamedResponse;

class DocumentoArchivoController extends Controller
{
    /**
     * GET /panel/documentos/{documento}/archivo — foto o PDF de un documento
     * (carnet, licencia…). Son privados: solo los ve un administrador con
     * sesión abierta en el panel.
     */
    public function __invoke(Request $request, Documento $documento): StreamedResponse
    {
        abort_unless($request->user()?->es_admin, 403);

        $disco = Storage::disk(config('filesystems.privado_disk'));
        abort_unless($disco->exists($documento->archivo_url), 404);

        return $disco->response($documento->archivo_url, null, ['Cache-Control' => 'private, max-age=600']);
    }
}
