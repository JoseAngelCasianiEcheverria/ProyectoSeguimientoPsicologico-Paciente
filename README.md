# Mindjora · Pacientes

Portal web del paciente de **Mindjora**. Aplicacion Flutter (web) donde el
paciente consulta sus sesiones, su agenda, su diario y sus tests.

Es un cliente: todo el backend vive en un proyecto de Supabase compartido con
el portal del psicologo. Este repositorio no contiene ni migraciones ni
funciones de servidor propias.

## Requisitos

- Flutter `3.47.3` (la misma version que usa la imagen de Docker).
- Un proyecto de Supabase con el esquema del portal ya aplicado.

## Desarrollo local

```bash
cp .env.example .env      # completar SUPABASE_URL y SUPABASE_PUBLISHABLE_KEY
flutter pub get
flutter run -d chrome --dart-define-from-file=.env
```

La configuracion llega en tiempo de compilacion (`String.fromEnvironment`), no
por `.env` en tiempo de ejecucion: cambiar una clave exige recompilar.

## Build web

```bash
flutter build web --release --no-web-resources-cdn --dart-define-from-file=.env
```

`--no-web-resources-cdn` es obligatorio: sirve CanvasKit desde el propio
origen, que es lo que permite la CSP de `web/index.html`. Sin el flag la app
queda en blanco porque la CSP bloquea `gstatic`.

## Docker y Render

```bash
docker compose up --build    # http://localhost:8080
```

`Dockerfile` compila con Flutter dentro de `debian:bookworm-slim` y sirve el
resultado con `nginx:alpine`. `render.yaml` despliega esa misma imagen en
Render (runtime Docker) y espera `SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY`
como variables de entorno.

## Pruebas

```bash
flutter analyze
flutter test
```

## Notas

- `web/_headers` usa el formato de Netlify y Cloudflare Pages. Como aqui se
  sirve con nginx, la version equivalente esta en `tools/nginx-security.conf`,
  que el `Dockerfile` copia a `conf.d/`; si se despliega en Netlify o Pages, se
  usa `web/_headers` directamente.
- `sql/` guarda las migraciones del lado paciente **ya aplicadas** al proyecto
  de Supabase, como referencia. El esquema lo administra el repositorio del
  portal del psicologo: no se ejecutan desde aqui.
- Nunca se versiona `.env`. La clave publica de Supabase es segura en el
  cliente; la seguridad la aplican las politicas RLS.
