{{--
    Lee el código QR de la foto de una licencia o permiso, en el navegador del
    administrador (la foto no sale del panel). Muestra el enlace que trae el QR
    para abrir la página de la Alcaldía y comparar: nombre, dirección, rubro y
    vigencia. Usa jsQR 1.4.0 (Apache-2.0), guardado en public/js.
    Estado: la dirección de la foto (route panel.documento.archivo).
--}}
@php($foto = $getState())
<div
    x-data="{
        estado: 'listo',
        texto: null,
        enlace: null,
        dominio: null,
        async cargarLector() {
            if (window.jsQR) return;
            await new Promise((ok, mal) => {
                const script = document.createElement('script');
                script.src = @js(asset('js/jsqr-1.4.0.js'));
                script.onload = ok;
                script.onerror = mal;
                document.head.appendChild(script);
            });
        },
        async leer() {
            this.estado = 'leyendo';
            this.texto = this.enlace = this.dominio = null;
            try {
                await this.cargarLector();
                const imagen = new Image();
                imagen.src = @js($foto);
                await imagen.decode();
                // Primero achicada (rápido); si no lo encuentra, más grande.
                const lado = Math.max(imagen.naturalWidth, imagen.naturalHeight);
                for (const maximo of [1600, 2600, lado]) {
                    const escala = Math.min(1, maximo / lado);
                    const ancho = Math.round(imagen.naturalWidth * escala);
                    const alto = Math.round(imagen.naturalHeight * escala);
                    const lienzo = document.createElement('canvas');
                    lienzo.width = ancho;
                    lienzo.height = alto;
                    const dibujo = lienzo.getContext('2d', { willReadFrequently: true });
                    dibujo.drawImage(imagen, 0, 0, ancho, alto);
                    const codigo = window.jsQR(dibujo.getImageData(0, 0, ancho, alto).data, ancho, alto, { inversionAttempts: 'attemptBoth' });
                    if (codigo && codigo.data) {
                        this.texto = codigo.data;
                        try {
                            const url = new URL(codigo.data);
                            // Solo enlaces web: nunca javascript: ni otros esquemas.
                            if (url.protocol === 'https:' || url.protocol === 'http:') {
                                this.enlace = url.href;
                                this.dominio = url.hostname;
                            }
                        } catch (e) {}
                        this.estado = 'leido';
                        return;
                    }
                    if (escala === 1) break;
                }
                this.estado = 'sin_qr';
            } catch (e) {
                this.estado = 'error';
            }
        },
    }"
    style="display:grid;gap:.75rem"
>
    <x-filament::button type="button" color="gray" icon="heroicon-o-qr-code" x-on:click="leer()" x-bind:disabled="estado === 'leyendo'">
        <span x-text="estado === 'leyendo' ? 'Leyendo el QR…' : 'Leer el QR de la foto'"></span>
    </x-filament::button>

    <p x-show="estado === 'sin_qr'" x-cloak style="font-size:.875rem;color:var(--gray-500)">
        No se encontró un QR en la foto. Ábrela en grande y escanéala con la cámara de tu celular, o pide una foto más nítida.
    </p>
    <p x-show="estado === 'error'" x-cloak style="font-size:.875rem;color:var(--danger-600)">
        No se pudo leer la foto. Ábrela y escanea el QR con la cámara de tu celular.
    </p>

    <div x-show="estado === 'leido'" x-cloak style="display:grid;gap:.5rem;font-size:.875rem">
        <template x-if="enlace">
            <div style="display:grid;gap:.5rem">
                <p>
                    El QR lleva a: <strong x-text="dominio"></strong>
                </p>
                <p x-show="dominio && !dominio.endsWith('.bo')" style="font-weight:600;color:var(--danger-600)">
                    Ojo: no es una página de Bolivia (.bo). Podría ser una licencia falsa: no ingreses datos en esa página.
                </p>
                <p style="color:var(--gray-500)">
                    Revisa que sea la página oficial de la Alcaldía y compara el nombre del negocio, la dirección,
                    la actividad o rubro y si está vigente, con deudas o clausurado.
                </p>
                <x-filament::link x-bind:href="enlace" target="_blank" rel="noopener noreferrer" icon="heroicon-o-arrow-top-right-on-square">
                    Abrir la página del QR
                </x-filament::link>
            </div>
        </template>
        <template x-if="!enlace">
            <p>
                El QR no trae un enlace, solo este texto: <strong style="word-break:break-all" x-text="texto"></strong>
            </p>
        </template>
    </div>
</div>
