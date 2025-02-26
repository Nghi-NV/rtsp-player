//
//  RTSPClientDelegate.swift
//  RtspPlayer
//
//  Created by Nghi Nguyen on 26/2/25.
//

protocol RTSPClientDelegate: AnyObject {
    func onRtspStatusConnecting()
    func onRtspStatusConnected()
    func onRtspStatusDisconnected()
    func onRtspStatusFailedUnauthorized()
    func onRtspStatusFailed(message: String)
    func onRtspFirstFrameRendered()
}
