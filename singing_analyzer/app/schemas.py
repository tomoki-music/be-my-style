from typing import Any, Dict, Optional

from pydantic import BaseModel, Field


class HealthResponse(BaseModel):
    status: str


class DiagnosisResponse(BaseModel):
    overall_score: int = Field(..., ge=0, le=100)
    pitch_score: int = Field(..., ge=0, le=100)
    rhythm_score: int = Field(..., ge=0, le=100)
    expression_score: int = Field(..., ge=0, le=100)
    schema_version: int = 1
    performance_type: str = "vocal"
    common: Dict[str, int] = Field(default_factory=dict)
    specific: Dict[str, int] = Field(default_factory=dict)
    reference_comparison: Dict[str, Any] = Field(default_factory=dict)
    analysis_debug: Dict[str, Any] = Field(default_factory=dict)
    quality_flags: Dict[str, bool] = Field(default_factory=dict)
    quality_message: Optional[str] = None
