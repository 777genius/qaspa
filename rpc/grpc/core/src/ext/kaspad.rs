use kaspa_notify::{scope::Scope, subscription::Command};
use kaspa_rpc_core::RpcError;

use crate::protowire::{
    kaspad_request, kaspad_response, KaspadRequest, KaspadResponse, NotifyBlockAddedRequestMessage,
    NotifyFinalityConflictRequestMessage, NotifyNewBlockTemplateRequestMessage, NotifyPruningPointUtxoSetOverrideRequestMessage,
    NotifySinkBlueScoreChangedRequestMessage, NotifyUtxosChangedRequestMessage, NotifyVirtualChainChangedRequestMessage,
    NotifyVirtualDaaScoreChangedRequestMessage,
};

impl KaspadRequest {
    pub fn from_notification_type(scope: &Scope, command: Command) -> Self {
        KaspadRequest { id: 0, payload: Some(kaspad_request::Payload::from_notification_type(scope, command)) }
    }

    pub fn try_from_notification_type(scope: &Scope, command: Command) -> Result<Self, RpcError> {
        Ok(KaspadRequest { id: 0, payload: Some(kaspad_request::Payload::try_from_notification_type(scope, command)?) })
    }

    pub fn is_subscription(&self) -> bool {
        self.payload.as_ref().is_some_and(|x| x.is_subscription())
    }
}

impl kaspad_request::Payload {
    pub fn from_notification_type(scope: &Scope, command: Command) -> Self {
        Self::try_from_notification_type(scope, command)
            .unwrap_or_else(|_| panic!("MasterDelegationExpiringSoon notification is not supported over gRPC. Use wRPC instead."))
    }

    pub fn try_from_notification_type(scope: &Scope, command: Command) -> Result<Self, RpcError> {
        Ok(match scope {
            Scope::BlockAdded(ref scope) => kaspad_request::Payload::NotifyBlockAddedRequest(NotifyBlockAddedRequestMessage {
                command: command.into(),
                include_stealth_outputs: scope.include_stealth_outputs,
            }),
            Scope::NewBlockTemplate(_) => {
                kaspad_request::Payload::NotifyNewBlockTemplateRequest(NotifyNewBlockTemplateRequestMessage {
                    command: command.into(),
                })
            }

            Scope::VirtualChainChanged(ref scope) => {
                kaspad_request::Payload::NotifyVirtualChainChangedRequest(NotifyVirtualChainChangedRequestMessage {
                    command: command.into(),
                    include_accepted_transaction_ids: scope.include_accepted_transaction_ids,
                })
            }
            Scope::FinalityConflict(_) | Scope::FinalityConflictResolved(_) => {
                kaspad_request::Payload::NotifyFinalityConflictRequest(NotifyFinalityConflictRequestMessage {
                    command: command.into(),
                })
            }
            Scope::UtxosChanged(ref scope) => kaspad_request::Payload::NotifyUtxosChangedRequest(NotifyUtxosChangedRequestMessage {
                addresses: scope.addresses.iter().map(|x| x.into()).collect::<Vec<String>>(),
                command: command.into(),
            }),
            Scope::SinkBlueScoreChanged(_) => {
                kaspad_request::Payload::NotifySinkBlueScoreChangedRequest(NotifySinkBlueScoreChangedRequestMessage {
                    command: command.into(),
                })
            }
            Scope::VirtualDaaScoreChanged(_) => {
                kaspad_request::Payload::NotifyVirtualDaaScoreChangedRequest(NotifyVirtualDaaScoreChangedRequestMessage {
                    command: command.into(),
                })
            }
            Scope::PruningPointUtxoSetOverride(_) => {
                kaspad_request::Payload::NotifyPruningPointUtxoSetOverrideRequest(NotifyPruningPointUtxoSetOverrideRequestMessage {
                    command: command.into(),
                })
            }
            Scope::StealthUtxosChanged(_) => {
                // TODO: Add protobuf message for StealthUtxosChanged when gRPC support is implemented
                // For now, use regular UtxosChanged with empty addresses (will be filtered by version)
                kaspad_request::Payload::NotifyUtxosChangedRequest(NotifyUtxosChangedRequestMessage {
                    addresses: vec![],
                    command: command.into(),
                })
            }
            Scope::MasterDelegationExpiringSoon(_) => return Err(RpcError::UnsupportedFeature),
        })
    }

    pub fn is_subscription(&self) -> bool {
        use crate::protowire::kaspad_request::Payload;
        matches!(
            self,
            Payload::NotifyBlockAddedRequest(_)
                | Payload::NotifyVirtualChainChangedRequest(_)
                | Payload::NotifyFinalityConflictRequest(_)
                | Payload::NotifyUtxosChangedRequest(_)
                | Payload::NotifySinkBlueScoreChangedRequest(_)
                | Payload::NotifyVirtualDaaScoreChangedRequest(_)
                | Payload::NotifyPruningPointUtxoSetOverrideRequest(_)
                | Payload::NotifyNewBlockTemplateRequest(_)
                | Payload::StopNotifyingUtxosChangedRequest(_)
                | Payload::StopNotifyingPruningPointUtxoSetOverrideRequest(_)
        )
    }
}

impl KaspadResponse {
    pub fn is_notification(&self) -> bool {
        match self.payload {
            Some(ref payload) => payload.is_notification(),
            None => false,
        }
    }
}

#[allow(clippy::match_like_matches_macro)]
impl kaspad_response::Payload {
    pub fn is_notification(&self) -> bool {
        use crate::protowire::kaspad_response::Payload;
        match self {
            Payload::BlockAddedNotification(_) => true,
            Payload::VirtualChainChangedNotification(_) => true,
            Payload::FinalityConflictNotification(_) => true,
            Payload::FinalityConflictResolvedNotification(_) => true,
            Payload::UtxosChangedNotification(_) => true,
            Payload::SinkBlueScoreChangedNotification(_) => true,
            Payload::VirtualDaaScoreChangedNotification(_) => true,
            Payload::PruningPointUtxoSetOverrideNotification(_) => true,
            Payload::NewBlockTemplateNotification(_) => true,
            _ => false,
        }
    }
}
