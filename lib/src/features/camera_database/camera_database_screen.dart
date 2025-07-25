import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'camera_data_service.dart';
import 'camera_database_viewmodel.dart';
import 'models/camera_data.dart';

class CameraDatabaseScreen extends StatefulWidget {
  const CameraDatabaseScreen({super.key});

  @override
  State<CameraDatabaseScreen> createState() => _CameraDatabaseScreenState();
}

class _CameraDatabaseScreenState extends State<CameraDatabaseScreen> {
  late final CameraDatabaseViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = CameraDatabaseViewModel(CameraDataService());
    _viewModel.initialize();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('相机数据'),
          actions: [
            Consumer<CameraDatabaseViewModel>(
              builder: (context, viewModel, child) {
                return Row(
                  children: [
                    const Text('对比'),
                    Switch(
                      value: viewModel.isCompareMode,
                      onChanged: (value) {
                        viewModel.toggleCompareMode();
                      },
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed:
                          viewModel.selectedBrand != null &&
                              viewModel.selectedModel != null
                          ? viewModel.search
                          : null,
                      child: const Text('查询'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        body: Consumer<CameraDatabaseViewModel>(
          builder: (context, viewModel, child) {
            if (viewModel.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (viewModel.error != null) {
              return Center(child: Text('加载数据失败: ${viewModel.error}'));
            }
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildSelectors(context, viewModel),
                  const SizedBox(height: 20),
                  Expanded(child: _buildResults(viewModel)),
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text(
                      '数据来源：leavestylecode/CameraDatabase',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSelectors(
    BuildContext context,
    CameraDatabaseViewModel viewModel,
  ) {
    if (viewModel.isCompareMode) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildSelectorColumn(context, viewModel, isSecond: false),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildSelectorColumn(context, viewModel, isSecond: true),
          ),
        ],
      );
    } else {
      return _buildSelectorRow(context, viewModel);
    }
  }

  Widget _buildSelectorColumn(
    BuildContext context,
    CameraDatabaseViewModel viewModel, {
    bool isSecond = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButton<String>(
          isExpanded: true,
          hint: Text(isSecond ? '选择对比品牌' : '选择品牌'),
          value: isSecond ? viewModel.selectedBrand2 : viewModel.selectedBrand,
          items: viewModel.brands.map((String value) {
            return DropdownMenuItem<String>(value: value, child: Text(value));
          }).toList(),
          onChanged: (newValue) {
            viewModel.selectBrand(newValue, isSecond: isSecond);
          },
        ),
        const SizedBox(height: 10),
        DropdownButton<String>(
          isExpanded: true,
          hint: Text(isSecond ? '选择对比型号' : '选择型号'),
          value: isSecond ? viewModel.selectedModel2 : viewModel.selectedModel,
          items: (isSecond ? viewModel.models2 : viewModel.models).map((
            String value,
          ) {
            return DropdownMenuItem<String>(value: value, child: Text(value));
          }).toList(),
          onChanged: (newValue) {
            viewModel.selectModel(newValue, isSecond: isSecond);
          },
        ),
      ],
    );
  }

  Widget _buildSelectorRow(
    BuildContext context,
    CameraDatabaseViewModel viewModel, {
    bool isSecond = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: DropdownButton<String>(
            isExpanded: true,
            hint: Text(isSecond ? '选择对比品牌' : '选择品牌'),
            value: isSecond
                ? viewModel.selectedBrand2
                : viewModel.selectedBrand,
            items: viewModel.brands.map((String value) {
              return DropdownMenuItem<String>(value: value, child: Text(value));
            }).toList(),
            onChanged: (newValue) {
              viewModel.selectBrand(newValue, isSecond: isSecond);
            },
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: DropdownButton<String>(
            isExpanded: true,
            hint: Text(isSecond ? '选择对比型号' : '选择型号'),
            value: isSecond
                ? viewModel.selectedModel2
                : viewModel.selectedModel,
            items: (isSecond ? viewModel.models2 : viewModel.models).map((
              String value,
            ) {
              return DropdownMenuItem<String>(value: value, child: Text(value));
            }).toList(),
            onChanged: (newValue) {
              viewModel.selectModel(newValue, isSecond: isSecond);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResults(CameraDatabaseViewModel viewModel) {
    if (viewModel.isCompareMode) {
      return Row(
        children: [
          Expanded(
            child: viewModel.cameraData != null
                ? _buildDataDisplay(viewModel.cameraData!)
                : const Center(child: Text('请选择左侧相机。')),
          ),
          const VerticalDivider(),
          Expanded(
            child: viewModel.cameraData2 != null
                ? _buildDataDisplay(viewModel.cameraData2!)
                : const Center(child: Text('请选择右侧相机。')),
          ),
        ],
      );
    } else {
      return viewModel.cameraData != null
          ? _buildDataDisplay(viewModel.cameraData!)
          : const Center(child: Text('请选择品牌和型号后查询。'));
    }
  }

  Widget _buildDataDisplay(CameraData data) {
    return ListView(
      children: [
        _buildSectionCard('基本信息', [
          _buildInfoTile('型号', data.model),
          _buildInfoTile('年份', data.year),
          _buildInfoTile('重量', data.weight),
          _buildInfoTile('尺寸', data.dimensions),
          _buildInfoTile('电池', data.battery),
          _buildInfoTile('USB', data.usb),
          _buildInfoTile('取景器', data.viewfinder),
          _buildInfoTile('屏幕分辨率', data.screenResolution),
        ]),
        _buildSectionCard('传感器信息', [
          _buildInfoTile('传感器类型', data.sensorType),
          _buildInfoTile('传感器尺寸', data.sensorSize),
          _buildInfoTile('传感器分辨率', data.sensorResolution),
          _buildInfoTile('有效像素(百万像素)', data.effectiveMegapixels),
          _buildInfoTile('裁切系数', data.cropFactor),
        ]),
        _buildSectionCard('规格参数', [
          _buildInfoTile('ISO', data.iso),
          _buildInfoTile('最大图像分辨率', data.maxImageResolution),
          _buildInfoTile('最大快门速度', data.maxShutterSpeed),
          _buildInfoTile('最大视频分辨率', data.maxVideoResolution),
          _buildInfoTile('光学变焦', data.opticalZoom),
          _buildInfoTile('曝光补偿', data.exposureCompensation),
          _buildInfoTile('测光', data.metering),
          _buildInfoTile('存储类型', data.storageTypes),
        ]),
      ],
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(String title, String subtitle) {
    final String displaySubtitle =
        (subtitle.isEmpty || subtitle.toLowerCase() == 'null')
        ? '未知'
        : subtitle;
    return ListTile(title: Text(title), subtitle: Text(displaySubtitle));
  }
}
