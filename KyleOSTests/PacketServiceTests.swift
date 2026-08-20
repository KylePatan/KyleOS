import XCTest
import SwiftData
@testable import KyleOS

final class PacketServiceTests: XCTestCase {
    private typealias Project = ProjectService.Project
    private typealias Document = DocumentService.Document

    func testCreatePacketStoresTitleAndTargetName() throws {
        let context = ModelContext(PersistenceController.makeInMemoryContainer())
        let packet = PacketService.createPacket(title: "SNL Submission", targetName: "Saturday Night Live", context: context)
        try context.save()

        XCTAssertEqual(packet.title, "SNL Submission")
        XCTAssertEqual(packet.targetName, "Saturday Night Live")
        XCTAssertEqual(packet.items.count, 0)
    }

    func testAddProjectAddsAnItemAndIsIdempotent() throws {
        let context = ModelContext(PersistenceController.makeInMemoryContainer())
        let packet = PacketService.createPacket(title: "22 Minutes Submission", targetName: "This Hour Has 22 Minutes", context: context)
        let project = ProjectService.createProject(title: "Coastal Town", projectType: .tvPilot, in: context)
        try context.save()

        PacketService.addProject(project, to: packet, context: context)
        PacketService.addProject(project, to: packet, context: context) // dragging the same source twice
        try context.save()

        XCTAssertEqual(packet.items.count, 1, "Adding the same project twice must not duplicate the item")
        XCTAssertEqual(packet.items.first?.project?.id, project.id)
        XCTAssertEqual(PacketService.displayTitle(for: packet.items[0]), "Coastal Town")
    }

    func testAddDocumentAddsAnItemAndIsIdempotent() throws {
        let context = ModelContext(PersistenceController.makeInMemoryContainer())
        let packet = PacketService.createPacket(title: "Packet", targetName: "SNL", context: context)
        let project = ProjectService.createProject(title: "Sketch Pack", projectType: .other, in: context)
        let document = DocumentService.createDocument(title: "Airport Jokes", type: .prose, in: project, context: context)
        try context.save()

        PacketService.addDocument(document, to: packet, context: context)
        PacketService.addDocument(document, to: packet, context: context)
        try context.save()

        XCTAssertEqual(packet.items.count, 1)
        XCTAssertEqual(PacketService.displaySubtitle(for: packet.items[0]), "Prose · First Draft")
    }

    func testRemoveItemOnlyRemovesTheReferenceNotTheUnderlyingContent() throws {
        let context = ModelContext(PersistenceController.makeInMemoryContainer())
        let packet = PacketService.createPacket(title: "Packet", targetName: "SNL", context: context)
        let project = ProjectService.createProject(title: "Coastal Town", projectType: .tvPilot, in: context)
        PacketService.addProject(project, to: packet, context: context)
        try context.save()
        let item = packet.items[0]

        PacketService.removeItem(item, from: packet, context: context)
        try context.save()

        XCTAssertEqual(packet.items.count, 0)
        let survivingProjects = try context.fetch(FetchDescriptor<Project>())
        XCTAssertTrue(survivingProjects.contains { $0.id == project.id }, "Removing a packet item must never delete the underlying Project")
    }

    /// Proves the new `packetItems` cascade relationship (KyleOSSchemaV32) actually works: deleting
    /// a Project that's inside a Packet must clean up the dangling PacketItem, not leave a
    /// reference-to-nothing sitting in the packet.
    func testDeletingTheUnderlyingProjectRemovesItFromEveryPacket() throws {
        let context = ModelContext(PersistenceController.makeInMemoryContainer())
        let packet = PacketService.createPacket(title: "Packet", targetName: "SNL", context: context)
        let project = ProjectService.createProject(title: "Coastal Town", projectType: .tvPilot, in: context)
        PacketService.addProject(project, to: packet, context: context)
        try context.save()
        XCTAssertEqual(packet.items.count, 1)

        // ProjectService has no hard-delete action (Projects are only ever archived, CLAUDE.md
        // §5) — this test targets the new V32 schema cascade rule directly, the same way this
        // codebase's other cascade-relationship tests exercise ModelContext.delete directly.
        context.delete(project)
        try context.save()

        let items = try context.fetch(FetchDescriptor<PacketService.PacketItem>())
        XCTAssertTrue(items.isEmpty, "Deleting the Project must cascade-delete the PacketItem that referenced it")
    }

    /// Same proof for the Document side of the new relationship.
    func testDeletingTheUnderlyingDocumentRemovesItFromEveryPacket() throws {
        let context = ModelContext(PersistenceController.makeInMemoryContainer())
        let packet = PacketService.createPacket(title: "Packet", targetName: "SNL", context: context)
        let project = ProjectService.createProject(title: "Sketch Pack", projectType: .other, in: context)
        let document = DocumentService.createDocument(title: "Airport Jokes", type: .prose, in: project, context: context)
        PacketService.addDocument(document, to: packet, context: context)
        try context.save()
        XCTAssertEqual(packet.items.count, 1)

        DocumentService.delete(document, context: context)
        try context.save()

        let items = try context.fetch(FetchDescriptor<PacketService.PacketItem>())
        XCTAssertTrue(items.isEmpty, "Deleting the Document must cascade-delete the PacketItem that referenced it")
    }

    func testDeletingAPacketNeverDeletesTheUnderlyingProjectsOrDocuments() throws {
        let context = ModelContext(PersistenceController.makeInMemoryContainer())
        let packet = PacketService.createPacket(title: "Packet", targetName: "SNL", context: context)
        let project = ProjectService.createProject(title: "Coastal Town", projectType: .tvPilot, in: context)
        let document = DocumentService.createDocument(title: "Airport Jokes", type: .prose, in: project, context: context)
        PacketService.addProject(project, to: packet, context: context)
        PacketService.addDocument(document, to: packet, context: context)
        try context.save()

        PacketService.deletePacket(packet, context: context)
        try context.save()

        XCTAssertTrue(try context.fetch(FetchDescriptor<PacketService.PacketItem>()).isEmpty)
        XCTAssertFalse(try context.fetch(FetchDescriptor<Project>()).isEmpty, "Deleting a Packet must never delete the underlying Project")
        XCTAssertFalse(try context.fetch(FetchDescriptor<Document>()).isEmpty, "Deleting a Packet must never delete the underlying Document")
    }

    func testDisplaySubtitleDistinguishesSketchAndWritingProjects() throws {
        let context = ModelContext(PersistenceController.makeInMemoryContainer())
        let packet = PacketService.createPacket(title: "Packet", targetName: "SNL", context: context)
        let sketchProject = ProjectService.createProject(title: "Airport Sketch", projectType: .sketch, in: context)
        let writingProject = ProjectService.createProject(title: "Coastal Town", projectType: .tvPilot, in: context)
        PacketService.addProject(sketchProject, to: packet, context: context)
        PacketService.addProject(writingProject, to: packet, context: context)
        try context.save()

        let subtitles = Set(packet.items.map { PacketService.displaySubtitle(for: $0) })
        XCTAssertTrue(subtitles.contains("Sketch Project"))
        XCTAssertTrue(subtitles.contains("Writing Project"))
    }
}
