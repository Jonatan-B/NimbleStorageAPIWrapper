New-Variable -Name NimbleSession -Value @{} -Scope Global -Force -Description "Variable containing the current Nimble api session"
New-Variable -Name NimbleApiUrls  -Visibility Public -Scope Global -Force -Description "Variable containing the Api Urls used by the module" -Value @{
    GetToken = "https://{0}:5392/v1/tokens"
    GetVolumesOverview = "https://{0}:5392/v1/volumes"
    GetVolumesDetails = "https://{0}:5392/v1/volumes/detail"
    GetVolumeById = "https://{0}:5392/v1/volumes/{1}"
    GetInitiatorGroupsOverview = "https://{0}:5392/v1/initiator_groups"
    GetInitiatorGroupsDetails = "https://{0}:5392/v1/initiator_groups/detail"
    GetInitiatorGroupById = "https://{0}:5392/v1/initiator_groups/{1}"
    GetInitiatorsOverview = "https://{0}:5392/v1/initiators"
    GetInitiatorsDetails = "https://{0}:5392/v1/initiators/detail"
    GetInitiatorById = "https://{0}:5392/v1/initiators/{1}"
    GetNetworkAdapterOverview = "https://{0}:5392/v1/network_configs"
    GetNetworkAdapterDetails = "https://{0}:5392/v1/network_configs/detail"
    GetNetworkAdapaterById = "https://{0}:5392/v1/network_configs/{1}"
    GetVolumeCollectionOverview = "https://{0}:5392/v1/volume_collections"
    GetVolumeCollectionDetails = "https://{0}:5392/v1/volume_collections/detail"
    GetVolumeCollectionById = "https://{0}:5392/v1/volume_collections/{1}"
    GetACRecordsOverview = "https://{0}:5392/v1/access_control_records"
    GetACRecordsDetails = "https://{0}:5392/v1/access_control_records/detail"
    GetACRecordById = "https://{0}:5392/v1/access_control_records/{1}"
    InvokeVolumeCollectionHandover = "https://{0}:5392/v1/volume_collections/id/actions/handover"
}
