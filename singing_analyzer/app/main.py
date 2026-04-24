from fastapi import FastAPI, File, Form, UploadFile

from app.schemas import DiagnosisResponse, HealthResponse
from app.services.diagnosis_analyzer import DiagnosisAnalyzer

app = FastAPI(title="Singing Analyzer API")


@app.get("/health", response_model=HealthResponse)
async def health() -> HealthResponse:
    return HealthResponse(status="ok")


@app.post("/diagnoses", response_model=DiagnosisResponse)
async def create_diagnosis(
    audio_file: UploadFile = File(...),
    diagnosis_id: str = Form(...),
    performance_type: str = Form("vocal"),
    song_title: str = Form(""),
    memo: str = Form(""),
    reference_key: str = Form(""),
    reference_bpm: str = Form(""),
) -> DiagnosisResponse:
    audio_bytes = await audio_file.read()
    analyzer = DiagnosisAnalyzer()

    return analyzer.analyze(
        audio_bytes=audio_bytes,
        filename=audio_file.filename or "",
        content_type=audio_file.content_type or "",
        diagnosis_id=diagnosis_id,
        performance_type=performance_type,
        song_title=song_title,
        memo=memo,
        reference_key=reference_key,
        reference_bpm=reference_bpm,
    )
