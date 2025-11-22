from datetime import datetime
from typing import Optional, Any
from pydantic import BaseModel, Field


class CustomerIn(BaseModel):
    name: str
    metadata: Optional[dict[str, Any]] = Field(default_factory=dict)


class CustomerOut(CustomerIn):
    id: str
    created_at: datetime


class ProjectIn(BaseModel):
    customer_id: str
    name: str
    description: Optional[str] = None


class ProjectOut(ProjectIn):
    id: str
    created_at: datetime


class SiteIn(BaseModel):
    project_id: str
    name: str
    location: Optional[dict[str, Any]] = Field(default_factory=dict)


class SiteOut(SiteIn):
    id: str
    created_at: datetime


class DeviceIn(BaseModel):
    site_id: str
    name: str
    device_type: str
    external_id: Optional[str] = None
    status: Optional[str] = "active"


class DeviceOut(DeviceIn):
    id: str
    created_at: datetime


class ParamTemplateIn(BaseModel):
    key: str
    name: str
    unit: Optional[str] = None
    metadata: Optional[dict[str, Any]] = Field(default_factory=dict)


class ParamTemplateOut(ParamTemplateIn):
    id: str
    created_at: datetime


class PublishIn(BaseModel):
    author: str
    diff_json: dict[str, Any] = Field(default_factory=dict)


class PublishOut(BaseModel):
    status: str
    config_version: str


