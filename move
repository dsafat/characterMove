[RequireComponent(typeof(CharacterController))]
public class MovementScript : MonoBehaviour
{
    [Tooltip("角色控制器")] public CharacterController characterController;
    [Tooltip("重力加速度")] private float Gravity = 9.8f;
    private float horizontal;
    private float vertical;
    [Header("相机")]
    [Tooltip("摄像机相机")] public Transform mainCamera;
    [Tooltip("摄像机高度变化的平滑值")] public float interpolationSpeed = 10f;
    [Tooltip("当前摄像机的位置")] private Vector3 cameraLocalPosition;
    [Tooltip("当前摄像机的高度")] private float height;
    [Header("移动")]
    [Tooltip("角色行走的速度")] public float walkSpeed = 6f;
    [Tooltip("角色奔跑的速度")] public float runSpeed = 9f;
    [Tooltip("角色下蹲的速度")] public float crouchSpeed = 3f;
    [Tooltip("角色移动的方向")] private Vector3 moveDirection;
    [Tooltip("当前速度")] private float speed;
    [Tooltip("是否奔跑")] private bool isRun;
    [Header("地面检测")]
    [Tooltip("地面检测位置")] public Transform groundCheck;
    [Tooltip("地面检测半径")] public float sphereRadius = 0.4f;
    [Tooltip("是否在地面")] private bool isGround;
    [Header("头顶检测")]
    [Tooltip("头顶检测位置")] public Transform headCheck;
    [Tooltip("盒子半长、半宽、半高")] public Vector3 halfExtents = new Vector3(0.4f, 0.5f, 0.4f);
    [Tooltip("判断玩家是否可以站立")] private bool isCanStand;
    [Header("斜坡检测")]
    [Tooltip("斜坡射线长度")] public float slopeForceRayLength = 0.2f;
    [Tooltip("是否在斜坡")] private bool isSlope;
    [Header("跳跃")]
    [Tooltip("角色跳跃的高度")] public float jumpHeight = 2.5f;
    [Tooltip("判断是否在跳跃")] private bool isJumping;
    [Header("下蹲")]
    [Tooltip("下蹲时候的玩家高度")] private float crouchHeight;
    [Tooltip("判断玩家是否在下蹲")] private bool isCrouching;
    [Tooltip("正常站立时玩家高度")] private float standHeight;
    [Header("斜坡")]
    [Tooltip("走斜坡时施加的力度")] public float slopeForce = 6.0f;
    void Start()
    {
        standHeight = characterController.height;
        crouchHeight = standHeight / 2;
        cameraLocalPosition = mainCamera.localPosition;
        speed = walkSpeed;
    }
    void Update()
    {
        horizontal = Input.GetAxis("Horizontal");
        vertical = Input.GetAxis("Vertical");
        //地面检测
        isGround = IsGrounded();
        //头顶检测
        isCanStand = CanStand();
        //斜坡检测
        isSlope = OnSlope();
        SetSpeed();
        SetRun();
        SetCrouch();
        SetMove();
        SetJump();
    }
    //速度设置
    void SetSpeed()
    {
        if (isRun)
        {
            speed = runSpeed;
        }
        else if (isCrouching)
        {
            speed = crouchSpeed;
        }
        else
        {
            speed = walkSpeed;
        }
    }
    //控制奔跑
    void SetRun()
    {
        if (Input.GetKey(KeyCode.LeftShift) && !isCrouching)
        {
            isRun = true;
        }
        else
        {
            isRun = false;
        }
    }
    //控制下蹲
    void SetCrouch()
    {
        if (Input.GetKey(KeyCode.LeftControl))
        {
            Crouch(true);
        }
        else
        {
            Crouch(false);
        }
    }
    //控制移动
    void SetMove()
    {
        if (isGround)
        {
            moveDirection = transform.right * horizontal + transform.forward * vertical; // 计算移动方向
            //将该向量从局部坐标系转换为世界坐标系，得到最终的移动方向
            // moveDirection = transform.TransformDirection(new Vector3(h, 0, v));
            moveDirection = moveDirection.normalized; // 归一化移动方向，避免斜向移动速度过快  
        }
    }
    //控制跳跃
    void SetJump()
    {
        if (Input.GetButtonDown("Jump") && isGround)
        {
            isJumping = true;
            moveDirection.y = jumpHeight;
        }
        moveDirection.y -= Gravity * Time.deltaTime;
        characterController.Move(moveDirection * Time.deltaTime * speed);
        //为了不影响跳跃，一定要在isJumping = false之前加力
        SetSlope();
        isJumping = false;
    }
    //控制斜坡
    public void SetSlope()
    {
        //如果处于斜坡
        if (isSlope && !isJumping)
        {
            //向下增加力
            moveDirection.y = characterController.height / 2 * slopeForceRayLength;
            characterController.Move(Vector3.down * characterController.height / 2 * slopeForce * Time.deltaTime);
        }
    }
    //newCrouching控制下蹲起立
    public void Crouch(bool newCrouching)
    {
        if (!newCrouching && !isCanStand) return; //准备起立时且头顶有东西，不能进行站立
        isCrouching = newCrouching;
        float targetHeight = isCrouching ? crouchHeight : standHeight;
        float heightChange = targetHeight - characterController.height; //计算高度变化
        characterController.height = targetHeight; //根据下蹲状态设置下蹲时候的高度和站立的高度
        characterController.center += new Vector3(0, heightChange / 2, 0); //根据高度变化调整中心位置
        // 设置下蹲站立时候的摄像机高度
        float heightTarget = isCrouching ? cameraLocalPosition.y / 2 + characterController.center.y : cameraLocalPosition.y;
        height = Mathf.Lerp(height, heightTarget, interpolationSpeed * Time.deltaTime);
        mainCamera.localPosition = new Vector3(cameraLocalPosition.x, height, cameraLocalPosition.z);
    }
    //是否可以起立,及头顶是否有物品
    bool CanStand()
    {
        Collider[] colliders = Physics.OverlapBox(headCheck.position, halfExtents);
        foreach (Collider collider in colliders)
        {
            //忽略角色自身和所有子集碰撞体
            if (collider.gameObject != gameObject && !IsChildOf(collider.transform, transform))
            {
                return false;
            }
        }
        return true;
    }
    //是否在地面
    bool IsGrounded()
    {
        Collider[] colliders = Physics.OverlapSphere(groundCheck.position, sphereRadius);
        foreach (Collider collider in colliders)
        {
            if (collider.gameObject != gameObject && !IsChildOf(collider.transform, transform)) // 忽略角色自身和所有子集碰撞体
            {
                return true;
            }
        }
        return false;
    }
    //是否在斜面
    public bool OnSlope()
    {
        RaycastHit hit;
        // 向下打出射线（检测是否在斜坡上）
        if (Physics.Raycast(transform.position + characterController.height / 2 * Vector3.down, Vector3.down, out hit, characterController.height / 2 * slopeForceRayLength))
        {
            // 如果接触到的点的法线，不在(0,1,0)的方向上，那么人物就在斜坡上
            if (hit.normal != Vector3.up)
                return true;
        }
        return false;
    }
    //判断child是否是parent的子集
    bool IsChildOf(Transform child, Transform parent)
    {
        while (child != null)
        {
            if (child == parent)
            {
                return true;
            }
            child = child.parent;
        }
        return false;
    }
    //在场景视图显示检测，方便调试
    private void OnDrawGizmos()
    {
        Gizmos.color = Color.red;
        //头顶检测可视化
        Gizmos.DrawWireCube(headCheck.position, halfExtents * 2f);
        //地面检测可视化
        Gizmos.DrawWireSphere(groundCheck.position, sphereRadius);
        //斜坡检测可视化
        Debug.DrawRay(transform.position + characterController.height / 2 * Vector3.down, Vector3.down * characterController.height / 2 * slopeForceRayLength, Color.blue);
    }
}
