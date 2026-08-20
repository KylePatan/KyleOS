import Foundation
import SwiftData

/// Reusable domain actions for the Packet module (CLAUDE.md §4), kept out of views.
///
/// Kyle (2026-08-19): "I want to add another section. PACKET. I am writing packets for places
/// like 'This Hour Has 22 Minutes' and 'Saturday Night Live'... Create a Packet, name the packet
/// of the show/production company I want to send it to, and from there I can pick the projects or
/// drafts or sketches or prose (series of jokes but NOT stand up) easily into the packet... have
/// multiple packets for shows and be able to edit and add things and remove easily." A Packet
/// curates *references* into existing Writing/Sketch content — it never duplicates or owns that
/// content, matching this codebase's general "one source of truth" pattern (same reasoning as
/// PostingItem referencing a Clip/Sketch rather than copying its fields).
enum PacketService {
    typealias Packet = KyleOSSchemaV33.Packet
    typealias PacketItem = KyleOSSchemaV33.PacketItem
    typealias Project = KyleOSSchemaV33.Project
    typealias Document = KyleOSSchemaV33.Document

    static func createPacket(title: String, targetName: String, context: ModelContext) -> Packet {
        let packet = Packet(title: title, targetName: targetName)
        context.insert(packet)
        return packet
    }

    static func updatePacket(_ packet: Packet, title: String, targetName: String) {
        packet.title = title
        packet.targetName = targetName
        packet.updatedAt = .now
    }

    static func deletePacket(_ packet: Packet, context: ModelContext) {
        context.delete(packet)
    }

    /// No-op if `project` is already in this packet — dragging the same source item twice
    /// shouldn't create a duplicate entry.
    static func addProject(_ project: Project, to packet: Packet, context: ModelContext) {
        guard !packet.items.contains(where: { $0.project?.id == project.id }) else { return }
        let item = PacketItem(packet: packet, project: project, order: packet.items.count)
        context.insert(item)
        packet.updatedAt = .now
    }

    /// No-op if `document` is already in this packet, same reasoning as `addProject`.
    static func addDocument(_ document: Document, to packet: Packet, context: ModelContext) {
        guard !packet.items.contains(where: { $0.document?.id == document.id }) else { return }
        let item = PacketItem(packet: packet, document: document, order: packet.items.count)
        context.insert(item)
        packet.updatedAt = .now
    }

    /// Removes the item from the packet only — the underlying Project/Document is untouched.
    static func removeItem(_ item: PacketItem, from packet: Packet, context: ModelContext) {
        context.delete(item)
        packet.updatedAt = .now
    }

    /// The name to show for one item's target — whichever of `project`/`document` is set. Falls
    /// back to "(removed)" for the edge case where both are somehow nil (e.g. a fetch mid-cascade-
    /// delete), rather than crashing a list row.
    static func displayTitle(for item: PacketItem) -> String {
        if let project = item.project { return project.title }
        if let document = item.document { return document.title }
        return "(removed)"
    }

    static func displaySubtitle(for item: PacketItem) -> String {
        if let project = item.project {
            return project.projectType == .sketch ? "Sketch Project" : "Writing Project"
        }
        if let document = item.document {
            return "\(document.documentType.rawValue) · \(document.displayDraftLabel)"
        }
        return ""
    }
}
