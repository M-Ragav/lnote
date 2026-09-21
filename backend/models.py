from typing import List, Optional
from pydantic import BaseModel, Field

class SessionModel(BaseModel):
    inTime: str
    outTime: Optional[str] = None
    tag: Optional[str] = None

class AttendanceDayModel(BaseModel):
    date: str
    sessions: List[SessionModel] = Field(default_factory=list)

class SkillModel(BaseModel):
    id: str
    name: str

class UserProfileModel(BaseModel):
    name: str
    birthday: str

class SyncRequest(BaseModel):
    deviceId: Optional[str] = None
    deviceName: Optional[str] = None
    clientTimestamp: Optional[str] = None
    attendanceDays: Optional[List[AttendanceDayModel]] = None
    skills: Optional[List[SkillModel]] = None
    profile: Optional[UserProfileModel] = None

class SyncResponse(BaseModel):
    status: str = "success"
    serverTimestamp: str
    attendanceDays: List[AttendanceDayModel]
    skills: List[SkillModel]
    profile: Optional[UserProfileModel] = None

class HealthResponse(BaseModel):
    status: str = "ok"
    version: str = "1.0.0"
    serverTimestamp: str
    totalDays: int = 0
    totalSessions: int = 0
