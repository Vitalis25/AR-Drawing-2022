import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController {

    // MARK: - Outlets
    @IBOutlet var sceneView: ARSCNView!
    
    // MARK: - Properties
    /// Visualize planes
    var arePlanesHidden = true {
        didSet {
            planeNodes.forEach { $0.isHidden = arePlanesHidden }
        }
    }
    
    let configuration = ARWorldTrackingConfiguration()
    
    /// Last node placed by user
    var lastNode: SCNNode?
    
    /// Minimum distance between objects placed when moving
    let minimumDistance: Float = 0.07
    
    enum ObjectPlacementMode {
        case freeform, plane, image
    }
    
    var objectMode: ObjectPlacementMode = .freeform
    
    /// Arrays of objects placed
    var objectsPlaced = [SCNNode]()
    
    /// Array of found planes
    var planeNodes = [SCNNode]()
    
    /// The node for the object currently selected by the user
    var selectedNode: SCNNode?
    
    // MARK: - Methods
    /// Adds a node at user's touch location represented by point
    /// - Parameters:
    ///   - node: the node to be added
    ///   - point: point at which user has touched the screen
    func addNode(_ node: SCNNode, at point: CGPoint) {
        guard let hitResult = sceneView.hitTest(point, types: .existingPlaneUsingExtent).first else { return }
        
        guard let anchor = hitResult.anchor as? ARPlaneAnchor, anchor.alignment == .horizontal else { return }
        
        node.simdTransform = hitResult.worldTransform
        addNodeToSceneRoot(node)
    }
    
    func addNode(_ node: SCNNode, to parentNode: SCNNode) {
        // Check that the object is not too close to the previous one
        if let lastNode = lastNode {
            let lastPosition = lastNode.position
            let newPosition = node.position
            
            let x = lastPosition.x - newPosition.x
            let y = lastPosition.y - newPosition.y
            let z = lastPosition.z - newPosition.z
            
            let distanceSquare = x * x + y * y + z * z
            let minimumDistanceSquare = minimumDistance * minimumDistance
            
            guard minimumDistanceSquare < distanceSquare else { return }
        }
        
        // Clone the node for creating separate copies of the object
        let clonedNode = node.clone()
        
        // Remember last placed node
        lastNode = clonedNode
        
        // Remember object placed for undo
        objectsPlaced.append(clonedNode)
        
        // Add the cloned node to the scene
        parentNode.addChildNode(clonedNode)
    }
    
    /// Adds an object in 20 cm in front of camera
    /// - Parameter node: node of the object to add
    func addNodeInFront(_ node: SCNNode) {
        // Get current camera frame
        guard let frame = sceneView.session.currentFrame else { return }
        
        // Get transform property of the camera
        let transform = frame.camera.transform
        
        // Create translation matrix
        var translation = matrix_identity_float4x4
        
        // Translate by 20 cm on z axis
        translation.columns.3.z = -0.2
        
        // Rotate by pi / 2 on z axis
        translation.columns.0.x = 0
        translation.columns.1.x = -1
        translation.columns.0.y = 1
        translation.columns.1.y = 0
        
        // Assign transform to the node
        node.simdTransform = matrix_multiply(transform, translation)
        
        // Add node to the scene
        addNodeToSceneRoot(node)
    }
    
    func addNodeToImage(_ node: SCNNode, at point: CGPoint) {
        guard let result = sceneView.hitTest(point, options: [:]).first else { return }
        guard result.node.name == "image" else { return }
        node.transform = result.node.worldTransform
        node.eulerAngles.x = 0
        addNodeToSceneRoot(node)
    }
    
    func addNodeToSceneRoot(_ node: SCNNode) {
        addNode(node, to: sceneView.scene.rootNode)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showOptions" {
            let optionsViewController = segue.destination as! OptionsContainerViewController
            optionsViewController.delegate = self
        }
    }
    
    func process(_ touches: Set<UITouch>) {
        guard let touch = touches.first, let selectedNode = selectedNode else { return }
        
        let point = touch.location(in: sceneView)
        
        switch objectMode {
        case .freeform:
            addNodeInFront(selectedNode)
        case .image:
            addNodeToImage(selectedNode, at: point)
        case .plane:
            addNode(selectedNode, at: point)
        }
    }
    
    func reloadConfiguration() {
        configuration.detectionImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: nil)
        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        lastNode = nil
        process(touches)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        process(touches)

    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        sceneView.autoenablesDefaultLighting = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadConfiguration()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }

    // MARK: - Actions
    @IBAction func changeObjectMode(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            objectMode = .freeform
            arePlanesHidden = true
        case 1:
            objectMode = .plane
            arePlanesHidden = false
        case 2:
            objectMode = .image
            arePlanesHidden = true
        default:
            break
        }
    }
}

// MARK: OptionsViewControllerDelegate
extension ViewController: OptionsViewControllerDelegate {
    
    func objectSelected(node: SCNNode) {
        dismiss(animated: true, completion: nil)
        selectedNode = node
    }
    
    func togglePlaneVisualization() {
        dismiss(animated: true, completion: nil)
        
        guard objectMode == .plane else { return }
        arePlanesHidden.toggle()
    }
    
    func undoLastObject() {
        print(#line, #function)
    }
    
    func resetScene() {
        print(#line, #function)
        dismiss(animated: true, completion: nil)
    }
}

// MARK: ARSCNViewDelegate
extension ViewController: ARSCNViewDelegate {
    func createFloor(with size: CGSize, opacity: CGFloat = 0.25) -> SCNNode {
        
        let plane = SCNPlane(width: size.width, height: size.height)
        plane.firstMaterial?.diffuse.contents = UIColor.green
        
        let planeNode = SCNNode(geometry: plane)
        planeNode.opacity = opacity
        planeNode.eulerAngles.x -= .pi / 2
        
        return planeNode
    }
    
    func nodeAdded(_ node: SCNNode, for anchor: ARImageAnchor) {
        // Put a plane at the image
        let size = anchor.referenceImage.physicalSize
        let coverNode = createFloor(with: size, opacity: 0.1)
        coverNode.name = "image"
        node.addChildNode(coverNode)
        
    }
    
    func nodeAdded(_ node: SCNNode, for anchor: ARPlaneAnchor) {
        let extent = anchor.extent
        let size = CGSize(width: CGFloat(extent.x), height: CGFloat(extent.z))
        let planeNode = createFloor(with: size)
        planeNode.isHidden = arePlanesHidden
        
        
        // Add plane node to the list of plane nodes
        planeNodes.append(planeNode)
        
        node.addChildNode(planeNode)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        switch anchor {
        case let imageAnchor as ARImageAnchor:
            nodeAdded(node, for: imageAnchor)
        case let planeAnchor as ARPlaneAnchor:
            nodeAdded(node, for: planeAnchor)
        default:
            print(#line, #function, "Unknown anchor type \(anchor) is found")
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        switch anchor {
        case is ARImageAnchor:
            break
        case let planeAnchor as ARPlaneAnchor:
            updateFloor(for: node, anchor: planeAnchor)
        default:
            print(#line, #function, "Unknown anchor type \(anchor) is updated")
        }
    }
    
    func updateFloor(for node: SCNNode, anchor: ARPlaneAnchor) {
        guard let planeNode = node.childNodes.first, let plane = planeNode.geometry as? SCNPlane else {
            print(#line, #function, "Can't find SCNPlane at node \(node)")
            return
        }
        
        // Get estimated plane size
        let extent = anchor.extent
        plane.width = CGFloat(extent.x)
        plane.height = CGFloat(extent.z)
        
        // Position the plane in the center
        planeNode.simdPosition = anchor.center
    }
}
