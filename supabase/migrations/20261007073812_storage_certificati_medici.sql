-- ============================================================
-- LA PALEXTRA
-- Migration: Storage privato certificati medici
-- ============================================================


-- ============================================================
-- 1. BUCKET PRIVATO
-- ============================================================

insert into storage.buckets (
    id,
    name,
    public,
    file_size_limit,
    allowed_mime_types
)
values (
    'certificati_medici',
    'certificati_medici',
    false,
    10485760,
    array[
        'application/pdf',
        'image/jpeg',
        'image/png'
    ]
)
on conflict (id) do update
set
    public = false,
    file_size_limit = 10485760,
    allowed_mime_types = array[
        'application/pdf',
        'image/jpeg',
        'image/png'
    ];


-- ============================================================
-- 2. LETTURA DEI CERTIFICATI
--
-- Struttura prevista:
--
-- certificati_medici/
--     <profilo_id>/
--         <identificativo_file>/
--             documento.pdf
--
-- Il primo elemento del percorso è il profilo dell'utente.
-- ============================================================

create policy certificati_medici_storage_select
on storage.objects
for select
to authenticated
using (
    bucket_id = 'certificati_medici'
    and (
        (storage.foldername(name))[1] = (select auth.uid())::text
        or public.utente_e_proprietario()
        or public.utente_ha_permesso('certificati.visualizza')
    )
);


-- ============================================================
-- 3. CARICAMENTO
--
-- Un atleta può caricare esclusivamente nella propria
-- cartella.
--
-- Proprietario/amministratore possono caricare per conto
-- dell'atleta.
-- ============================================================

create policy certificati_medici_storage_insert
on storage.objects
for insert
to authenticated
with check (
    bucket_id = 'certificati_medici'
    and (
        (storage.foldername(name))[1] = (select auth.uid())::text
        or public.utente_e_proprietario()
        or public.utente_ha_permesso('certificati.carica')
    )
);


-- ============================================================
-- 4. MODIFICA
-- ============================================================

create policy certificati_medici_storage_update
on storage.objects
for update
to authenticated
using (
    bucket_id = 'certificati_medici'
    and (
        (storage.foldername(name))[1] = (select auth.uid())::text
        or public.utente_e_proprietario()
        or public.utente_ha_permesso('certificati.carica')
    )
)
with check (
    bucket_id = 'certificati_medici'
    and (
        (storage.foldername(name))[1] = (select auth.uid())::text
        or public.utente_e_proprietario()
        or public.utente_ha_permesso('certificati.carica')
    )
);


-- ============================================================
-- 5. ELIMINAZIONE
--
-- L'atleta può eliminare solamente i propri file.
-- Proprietario/amministratore possono eliminarli.
-- ============================================================

create policy certificati_medici_storage_delete
on storage.objects
for delete
to authenticated
using (
    bucket_id = 'certificati_medici'
    and (
        (storage.foldername(name))[1] = (select auth.uid())::text
        or public.utente_e_proprietario()
        or public.utente_ha_permesso('certificati.carica')
    )
);